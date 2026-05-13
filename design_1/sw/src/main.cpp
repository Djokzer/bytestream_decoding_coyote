#include <cstdlib>
#include <iostream>
#include <fstream>
#include <vector>
#include <cstring>
#include <stdexcept>
#include <algorithm>
#include <thread>

#include <chrono>

#include <boost/program_options.hpp>
#include <coyote/cBench.hpp>
#include <coyote/cThread.hpp>

#define CORRECTION_DATA_SIZE 1833
#define DEFAULT_VFPGA_ID 0
// Each 32-bit word is placed in the LSBs of a 512-bit (64-byte) AXI-Stream beat
#define STREAM_WIDTH_BYTES 64

struct alignas(16) CaloCell {
    int   gain_and_online_ID;
    float energy;
    float time;
    int   q_and_p;
};

// Count FEB headers to pre-compute the expected number of decoded cells
static int compute_output_size(const std::vector<uint32_t>& raw) {
    int feb_count = 0;
    for (size_t i = 0; i + 3 < raw.size(); i++) {
        if (raw[i] == 0xee1234ee) {
            int rod_id = (raw[i + 3] & 0x00fff000) >> 12;
            if (rod_id == 0x410 || rod_id == 0x420 || rod_id == 0x430 || rod_id == 0x440 ||
                rod_id == 0x450 || rod_id == 0x460 || rod_id == 0x470 || rod_id == 0x480)
                feb_count++;
        }
    }
    return feb_count * 256;
}

// Write each 32-bit word into bytes [0:3] of its 64-byte slot; upper bytes are zeroed
static void pack_words_to_512(const std::vector<uint32_t>& words, uint8_t* buf) {
    for (size_t i = 0; i < words.size(); i++) {
        memset(buf + i * STREAM_WIDTH_BYTES, 0, STREAM_WIDTH_BYTES);
        memcpy(buf + i * STREAM_WIDTH_BYTES, &words[i], sizeof(uint32_t));
    }
}

void stream_correction_values(coyote::cThread& c_thread, uint8_t* corr_buf, uint32_t corr_buf_bytes)
{
    //std::cout << "Sending correction values to axis_host_recv[1]..." << std::endl;
    coyote::localSg corr_sg  = { .addr = corr_buf, .len = corr_buf_bytes, .stream = true, .dest = 1 };

    c_thread.invoke(coyote::CoyoteOper::LOCAL_READ, corr_sg);
    while (c_thread.checkCompleted(coyote::CoyoteOper::LOCAL_READ) != 1) {}
    c_thread.clearCompleted();
    //std::cout << "Correction values sent to axis_host_recv[1]." << std::endl;

}


int main(int argc, char* argv[]) {
    namespace po = boost::program_options;

    std::string raw_file, correction_file;
    po::options_description opts("Bytestream Decoder – Coyote host");
    opts.add_options()
        ("help,h",        "Show help")
        ("raw,r",         po::value<std::string>(&raw_file)->required(),        "Raw data binary file")
        ("correction,c",  po::value<std::string>(&correction_file)->required(), "Correction values binary file");

    po::variables_map vm;
    try {
        po::store(po::parse_command_line(argc, argv, opts), vm);
        if (vm.count("help")) { std::cout << opts << std::endl; return EXIT_SUCCESS; }
        po::notify(vm);
    } catch (const std::exception& e) {
        std::cerr << "Argument error: " << e.what() << "\n" << opts << std::endl;
        return EXIT_FAILURE;
    }

    // --- Load raw data ---
    std::ifstream fin_raw(raw_file, std::ios::binary);
    if (!fin_raw) { std::cerr << "Cannot open raw file: " << raw_file << std::endl; return EXIT_FAILURE; }
    std::vector<uint32_t> raw_words;
    {
        uint32_t w;
        while (fin_raw.read(reinterpret_cast<char*>(&w), sizeof(w)))
            raw_words.push_back(w);
    }
    std::cout << "Raw words loaded: " << raw_words.size() << std::endl;

    // --- Load correction data ---
    std::ifstream fin_corr(correction_file, std::ios::binary);
    if (!fin_corr) { std::cerr << "Cannot open correction file: " << correction_file << std::endl; return EXIT_FAILURE; }
    std::vector<uint32_t> corr_words;
    {
        uint32_t w;
        while (fin_corr.read(reinterpret_cast<char*>(&w), sizeof(w)))
            corr_words.push_back(w);
    }
    if ((int)corr_words.size() != CORRECTION_DATA_SIZE)
        std::cerr << "Warning: correction file has " << corr_words.size()
                  << " words, expected " << CORRECTION_DATA_SIZE << std::endl;

    // --- Compute expected output size (same FEB-counting logic as XRT host) ---
    const int output_cells = compute_output_size(raw_words);
    // Hardware produces 4 sequential 32-bit beats per CaloCell (gain_id, energy, time, q_and_p)
    const int output_words = output_cells * 4;
    std::cout << "Expected output cells: " << output_cells
              << "  (" << output_words << " 32-bit words)" << std::endl;

    // --- Allocate Coyote huge-page buffers ---
    // Each 32-bit word occupies one 512-bit (64-byte) AXI-Stream beat
    const size_t raw_buf_bytes  = raw_words.size()  * STREAM_WIDTH_BYTES;
    const size_t corr_buf_bytes = corr_words.size() * STREAM_WIDTH_BYTES;
    const size_t out_buf_bytes  = output_words       * STREAM_WIDTH_BYTES;

    coyote::cThread coyote_thread(DEFAULT_VFPGA_ID, getpid());

    auto* raw_buf  = static_cast<uint8_t*>(coyote_thread.getMem({coyote::CoyoteAllocType::HPF, raw_buf_bytes}));
    auto* corr_buf = static_cast<uint8_t*>(coyote_thread.getMem({coyote::CoyoteAllocType::HPF, corr_buf_bytes}));
    auto* out_buf  = static_cast<uint8_t*>(coyote_thread.getMem({coyote::CoyoteAllocType::HPF, out_buf_bytes}));

    if (!raw_buf || !corr_buf || !out_buf)
        throw std::runtime_error("Failed to allocate Coyote memory");

    pack_words_to_512(raw_words,  raw_buf);
    pack_words_to_512(corr_words, corr_buf);
    memset(out_buf, 0, out_buf_bytes);

    // STREAM CORRECTION VALUES
    auto t_corr_start = std::chrono::high_resolution_clock::now();
    stream_correction_values(coyote_thread, corr_buf, (uint32_t)corr_buf_bytes);
    std::cout << "Correction stream time: "
              << std::chrono::duration<double, std::milli>(std::chrono::high_resolution_clock::now() - t_corr_start).count()
              << " ms" << std::endl;

    // Launch parallel coyote threads for raw write and result get
    coyote::localSg raw_sg = { .addr = raw_buf, .len = (uint32_t)raw_buf_bytes, .stream = true, .dest = 0 };
    coyote::localSg out_sg = { .addr = out_buf, .len = (uint32_t)out_buf_bytes, .stream = true };

    auto t0 = std::chrono::high_resolution_clock::now();
    coyote_thread.invoke(coyote::CoyoteOper::LOCAL_READ, raw_sg);
    coyote_thread.invoke(coyote::CoyoteOper::LOCAL_WRITE, out_sg);
    while (coyote_thread.checkCompleted(coyote::CoyoteOper::LOCAL_READ) != 1) {}
    while (coyote_thread.checkCompleted(coyote::CoyoteOper::LOCAL_WRITE) != 1) {}
    coyote_thread.clearCompleted();
    coyote_thread.clearCompleted();
    auto transfer_time = std::chrono::duration<double, std::milli>(std::chrono::high_resolution_clock::now() - t0).count();

    std::cout << "Transfer time:  " << transfer_time << " ms" << std::endl;

    // -------------------------------------------------------------------
    // Unpack output: each 512-bit beat holds one 32-bit word in [31:0]
    // The decoder emits 4 words per cell: gain_id, energy, time, q_and_p
    // -------------------------------------------------------------------
    std::vector<CaloCell> results(output_cells);
    for (int i = 0; i < output_cells; i++) {
        memcpy(&results[i].gain_and_online_ID, out_buf + (i * 4 + 0) * STREAM_WIDTH_BYTES, sizeof(int));
        memcpy(&results[i].energy,             out_buf + (i * 4 + 1) * STREAM_WIDTH_BYTES, sizeof(float));
        memcpy(&results[i].time,               out_buf + (i * 4 + 2) * STREAM_WIDTH_BYTES, sizeof(float));
        memcpy(&results[i].q_and_p,            out_buf + (i * 4 + 3) * STREAM_WIDTH_BYTES, sizeof(int));
    }

    std::cout << "\nFirst decoded cells:" << std::endl;
    for (int i = 0; i < std::min(20, output_cells); i++) {
        std::cout << i
            << " Gain_and_ID = 0x" << std::hex << results[i].gain_and_online_ID
            << " Energy = "        << results[i].energy
            << " Time = "          << results[i].time
            << " Quality_and_Provenence = " << results[i].q_and_p
            << std::dec << std::endl;
    }

    std::cout << "\nFirst cells with non-zero time:" << std::endl;
    int shown = 0;
    for (int i = 0; i < output_cells && shown < 2; i++) {
        if (results[i].time != 0.0f) {
            std::cout << i
                << " Gain_and_ID = 0x" << std::hex << results[i].gain_and_online_ID
                << " Energy = "        << results[i].energy
                << " Time = "          << results[i].time
                << " Quality_and_Provenence = " << results[i].q_and_p
                << std::dec << std::endl;
            shown++;
        }
    }

    return EXIT_SUCCESS;
}
