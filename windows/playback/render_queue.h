#ifndef BANGUMI_PLAYBACK_RENDER_QUEUE_H_
#define BANGUMI_PLAYBACK_RENDER_QUEUE_H_

#include <functional>
#include <mutex>
#include <utility>

// Coalesce mpv callbacks without losing an update received during rendering.
// Post must enqueue work asynchronously on the single render thread.
class PlaybackRenderQueue {
 public:
  using Post = std::function<void(std::function<void()>)>;
  using Render = std::function<void(bool)>;

  PlaybackRenderQueue(Post post, Render render)
      : post_(std::move(post)), render_(std::move(render)) {}

  void Request(bool force = false) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (closed_) return;
    requested_ = true;
    force_ = force_ || force;
    if (!queued_) {
      queued_ = true;
      PostNext();
    }
  }

  // Serializes with both initial and follow-up posts. Once closed, a render
  // thread barrier can safely drain every task that references this object.
  void Close() {
    std::lock_guard<std::mutex> lock(mutex_);
    closed_ = true;
  }

 private:
  void PostNext() { post_([this]() { Run(); }); }

  void Run() {
    bool force;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      if (closed_) {
        queued_ = false;
        return;
      }
      requested_ = false;
      force = std::exchange(force_, false);
    }
    try {
      render_(force);
    } catch (...) {
      Complete();
      throw;
    }
    Complete();
  }

  void Complete() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!closed_ && requested_) {
      // Yield to pending resize/dispose work rather than spinning on frames.
      PostNext();
    } else {
      queued_ = false;
    }
  }

  Post post_;
  Render render_;
  std::mutex mutex_;
  bool requested_ = false;
  bool force_ = false;
  bool queued_ = false;
  bool closed_ = false;
};

#endif  // BANGUMI_PLAYBACK_RENDER_QUEUE_H_
