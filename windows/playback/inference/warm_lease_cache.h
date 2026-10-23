// Copyright (c) BangumiToday contributors. Licensed under the project MIT.
#pragma once

#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <utility>

namespace bangumi::inference {
// Exclusive leases share no execution state. Only the most recently requested
// idle value is retained; destruction and GPU retirement run outside the lock.
template <class T>
class WarmLeaseCache final {
 public:
  using Validate = std::function<bool(const T&)>;
  explicit WarmLeaseCache(Validate validate)
      : state_(std::make_shared<State>(std::move(validate))) {}

  template <class Create>
  std::shared_ptr<T> Acquire(const std::wstring& key, Create create) {
    auto state = state_;
    std::unique_ptr<T> value;
    std::unique_ptr<T> retired;
    uint64_t generation;
    {
      const std::lock_guard<std::mutex> lock(state->mutex);
      generation = ++state->generation;
      if (state->key == key) value = std::move(state->idle);
      else retired = std::move(state->idle);
    }
    retired.reset();  // Make room before allocating another model's GPU state.
    if (value && !state->Valid(*value)) value.reset();
    if (!value) value = create();
    return std::shared_ptr<T>(value.release(),
        [state, key, generation](T* returned) noexcept {
          std::unique_ptr<T> idle(returned);
          if (!idle || !state->Valid(*idle)) return;
          try {
            const std::lock_guard<std::mutex> lock(state->mutex);
            if (generation != state->generation) return;
            state->key = key;
            idle.swap(state->idle);
          } catch (...) {
            // Retention is optional, including under allocation pressure.
          }
        });
  }

  void Clear() {
    std::unique_ptr<T> retired;
    {
      const std::lock_guard<std::mutex> lock(state_->mutex);
      ++state_->generation;
      retired = std::move(state_->idle);
    }
  }

 private:
  struct State {
    explicit State(Validate value) : validate(std::move(value)) {}
    bool Valid(const T& value) const noexcept {
      try { return validate(value); } catch (...) { return false; }
    }
    const Validate validate;
    std::mutex mutex;
    std::wstring key;
    std::unique_ptr<T> idle;
    uint64_t generation = 0;
  };
  const std::shared_ptr<State> state_;
};
}  // namespace bangumi::inference
