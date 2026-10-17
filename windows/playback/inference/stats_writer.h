#ifndef BANGUMI_PLAYBACK_STATS_WRITER_H_
#define BANGUMI_PLAYBACK_STATS_WRITER_H_

#include <Windows.h>

#include <condition_variable>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <functional>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <utility>

namespace bangumi::inference {

// A stalled disk must not hold the filter's mutex or its playback thread.
// Keep at most one pending immutable snapshot; the newest counters supersede
// older ones. Forced phase/error snapshots wait for their ordered write, and
// destruction drains the final snapshot before the configuration is removed.
class PlaybackStatsWriter {
 public:
  using Write = std::function<void(const std::filesystem::path&,
                                  const std::string&)>;

  explicit PlaybackStatsWriter(Write write = WriteFile)
      : write_(std::move(write)), worker_([this] { Run(); }) {}

  ~PlaybackStatsWriter() {
    {
      const std::lock_guard<std::mutex> lock(mutex_);
      closing_ = true;
    }
    ready_.notify_one();
    worker_.join();
  }

  PlaybackStatsWriter(const PlaybackStatsWriter&) = delete;
  PlaybackStatsWriter& operator=(const PlaybackStatsWriter&) = delete;

  void Publish(std::filesystem::path path, std::string text, bool wait) {
    std::unique_lock<std::mutex> lock(mutex_);
    const auto sequence = ++sequence_;
    pending_ = Snapshot{std::move(path), std::move(text), sequence};
    ready_.notify_one();
    if (wait) drained_.wait(lock, [&] { return completed_ >= sequence; });
  }

 private:
  struct Snapshot {
    std::filesystem::path path;
    std::string text;
    uint64_t sequence;
  };

  static void WriteFile(const std::filesystem::path& path,
                        const std::string& text) {
    auto temporary = path;
    temporary += L".tmp";
    {
      std::ofstream stream(temporary, std::ios::binary | std::ios::trunc);
      stream.write(text.data(), static_cast<std::streamsize>(text.size()));
      stream.close();
      if (!stream) {
        std::error_code error;
        std::filesystem::remove(temporary, error);
        return;
      }
    }
    if (!MoveFileExW(temporary.c_str(), path.c_str(),
                     MOVEFILE_REPLACE_EXISTING)) {
      std::error_code error;
      std::filesystem::remove(temporary, error);
    }
  }

  void Run() {
    std::unique_lock<std::mutex> lock(mutex_);
    for (;;) {
      ready_.wait(lock, [&] { return closing_ || pending_.has_value(); });
      if (!pending_) return;
      auto snapshot = std::move(*pending_);
      pending_.reset();
      lock.unlock();
      try {
        write_(snapshot.path, snapshot.text);
      } catch (...) {
        // Diagnostics must never terminate playback, including on I/O errors.
      }
      lock.lock();
      completed_ = snapshot.sequence;
      drained_.notify_all();
    }
  }

  const Write write_;
  std::mutex mutex_;
  std::condition_variable ready_;
  std::condition_variable drained_;
  std::optional<Snapshot> pending_;
  uint64_t sequence_ = 0;
  uint64_t completed_ = 0;
  bool closing_ = false;
  std::thread worker_;
};

}  // namespace bangumi::inference

#endif  // BANGUMI_PLAYBACK_STATS_WRITER_H_
