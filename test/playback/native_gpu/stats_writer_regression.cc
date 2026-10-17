#include <chrono>
#include <condition_variable>
#include <filesystem>
#include <fstream>
#include <future>
#include <iostream>
#include <iterator>
#include <mutex>
#include <stdexcept>
#include <string>
#include <vector>

#include "inference/stats_writer.h"

namespace {
using bangumi::inference::PlaybackStatsWriter;

void Require(bool valid, const char* message) {
  if (!valid) throw std::runtime_error(message);
}

void CheckCoalescing() {
  std::mutex mutex;
  std::condition_variable changed;
  bool entered = false, release = false;
  std::vector<std::string> writes;
  {
    PlaybackStatsWriter writer([&](const auto&, const auto& text) {
      std::unique_lock<std::mutex> lock(mutex);
      writes.push_back(text);
      if (text == "first") {
        entered = true;
        changed.notify_all();
        changed.wait(lock, [&] { return release; });
      }
    });
    writer.Publish("unused", "first", false);
    {
      std::unique_lock<std::mutex> lock(mutex);
      changed.wait(lock, [&] { return entered; });
    }
    // The write is deliberately blocked. These calls must still return, with
    // only the newest snapshot retained for the worker to drain on destruction.
    for (int i = 0; i < 1000; ++i)
      writer.Publish("unused", std::to_string(i), false);
    {
      const std::lock_guard<std::mutex> lock(mutex);
      release = true;
    }
    changed.notify_all();
  }
  Require(writes == std::vector<std::string>({"first", "999"}),
          "Slow I/O blocked publication or retained obsolete snapshots");
}

void CheckForcedWrite() {
  std::mutex mutex;
  std::condition_variable changed;
  bool entered = false, release = false;
  PlaybackStatsWriter writer([&](const auto&, const auto&) {
    std::unique_lock<std::mutex> lock(mutex);
    entered = true;
    changed.notify_all();
    changed.wait(lock, [&] { return release; });
  });
  auto forced = std::async(std::launch::async, [&] {
    writer.Publish("unused", "failed", true);
  });
  bool pending;
  {
    std::unique_lock<std::mutex> lock(mutex);
    changed.wait(lock, [&] { return entered; });
    pending = forced.wait_for(std::chrono::milliseconds(0)) !=
              std::future_status::ready;
    release = true;
  }
  changed.notify_all();
  forced.get();
  Require(pending, "Forced state returned before its write completed");
}

void CheckFile() {
  const auto file = std::filesystem::current_path() / L"状态-writer.stats";
  const std::string text = "schemaVersion=1\nreason=中文诊断\n";
  {
    PlaybackStatsWriter writer;
    writer.Publish(file, "obsolete", true);
    for (int i = 0; i < 100; ++i) writer.Publish(file, text, false);
  }
  std::ifstream stream(file, std::ios::binary);
  const std::string actual{std::istreambuf_iterator<char>(stream),
                           std::istreambuf_iterator<char>()};
  stream.close();
  std::filesystem::remove(file);
  auto temporary = file;
  temporary += L".tmp";
  Require(actual == text, "Final UTF-8 snapshot was not drained atomically");
  Require(!std::filesystem::exists(temporary), "Temporary snapshot leaked");
  PlaybackStatsWriter writer([](const auto&, const auto&) {
    throw std::runtime_error("unavailable filesystem");
  });
  writer.Publish("unused", "failure", true);
}
}  // namespace

int main() {
  try {
    CheckCoalescing();
    CheckForcedWrite();
    CheckFile();
    std::cout << "PASS: nonblocking bounded snapshots, forced ordering, "
                 "shutdown drain, UTF-8 and I/O failures\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
