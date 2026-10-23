#include <atomic>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <thread>
#include <vector>

#include "inference/warm_lease_cache.h"

namespace {
struct Value {
  int id;
  bool valid = true;
  std::shared_ptr<int> lifetime = std::make_shared<int>(0);
};
using Cache = bangumi::inference::WarmLeaseCache<Value>;
void Require(bool condition, const char* reason) {
  if (!condition) throw std::runtime_error(reason);
}
void CheckReuse() {
  Cache cache([](const Value& v) { return v.valid; });
  int created = 0;
  auto create = [&] { return std::make_unique<Value>(Value{++created}); };
  auto first = cache.Acquire(L"gpu:model:720p", create);
  auto concurrent = cache.Acquire(L"gpu:model:720p", create);
  Require(first != concurrent && created == 2,
          "Concurrent Players shared mutable execution state");
  concurrent.reset();
  first.reset();
  auto reused = cache.Acquire(L"gpu:model:720p", create);
  Require(reused->id == 2 && created == 2,
          "An older Player evicted the more recently prepared session");
  reused->valid = false;
  reused.reset();
  Require(cache.Acquire(L"gpu:model:720p", create)->id == 3,
          "Faulted state was reused");
}
void CheckInvalidation() {
  bool metadata_matches = true;
  Cache cache([&](const Value&) { return metadata_matches; });
  int created = 0;
  auto create = [&] { return std::make_unique<Value>(Value{++created}); };
  cache.Acquire(L"gpu:model:720p", create).reset();
  metadata_matches = false;
  auto replaced = cache.Acquire(L"gpu:model:720p", create);
  Require(replaced->id == 2, "Changed cache metadata was ignored");
  metadata_matches = true;
  replaced.reset();
  auto active = cache.Acquire(L"gpu:model:720p", create);
  cache.Clear();
  active.reset();
  Require(cache.Acquire(L"gpu:model:720p", create)->id == 3,
          "Pre-clear leases repopulated the cleared cache");
  cache.Clear();
}
void CheckBoundAndThreads() {
  Cache cache([](const Value&) { return true; });
  int created = 0;
  auto create = [&] { return std::make_unique<Value>(Value{++created}); };
  std::weak_ptr<Value> first;
  {
    auto value = cache.Acquire(L"720p", create);
    first = value;
  }
  // shared_ptr control blocks retire on return; the unique value remains idle.
  Require(first.expired(), "An idle value retained a checked-out control block");
  cache.Acquire(L"1080p", create).reset();
  Require(cache.Acquire(L"720p", create)->id == 3,
          "More than one idle model/shape was retained");
  std::weak_ptr<int> prior_lifetime;
  {
    auto value = cache.Acquire(L"old-model", create);
    prior_lifetime = value->lifetime;
  }
  Require(!prior_lifetime.expired(), "Latest idle session was discarded");
  cache.Acquire(L"new-model", [&] {
    Require(prior_lifetime.expired(),
            "Idle GPU memory was not freed before preparing a different model");
    return create();
  }).reset();
  std::atomic<int> thread_created{0};
  std::vector<std::thread> workers;
  for (int i = 0; i < 8; ++i) {
    workers.emplace_back([&] {
      for (int n = 0; n < 200; ++n) {
        auto value = cache.Acquire(L"parallel", [&] {
          return std::make_unique<Value>(Value{++thread_created});
        });
        if (n % 13 == 0) cache.Clear();
      }
    });
  }
  for (auto& worker : workers) worker.join();
  cache.Clear();
}
}  // namespace

int main() {
  try {
    CheckReuse();
    CheckInvalidation();
    CheckBoundAndThreads();
    std::cout << "PASS: exclusive warm handoff, newest request retention, "
                 "metadata/fault invalidation, clear and concurrent leases\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
