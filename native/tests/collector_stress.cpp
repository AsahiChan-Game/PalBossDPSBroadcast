#include "CollectorCore.hpp"

#include <atomic>
#include <cassert>
#include <chrono>
#include <cmath>
#include <iostream>
#include <mutex>
#include <thread>
#include <vector>

int main()
{
    constexpr std::size_t thread_count = 8;
    constexpr std::size_t hits_per_thread = 250000;
    constexpr double damage_per_hit = 7.25;

    boss_dps::CollectorCore collector;
    std::mutex collector_mutex;
    std::vector<std::thread> workers;
    const auto started = std::chrono::steady_clock::now();

    for (std::size_t thread_index = 0; thread_index < thread_count; ++thread_index)
    {
        workers.emplace_back([&, thread_index] {
            const boss_dps::DamageKey key{
                .defender = 0x1000,
                .attacker = 0x2000 + thread_index,
                .damage_causer = 0x3000 + thread_index,
            };
            for (std::size_t hit = 0; hit < hits_per_thread; ++hit)
            {
                std::scoped_lock lock{collector_mutex};
                collector.add(key, damage_per_hit);
            }
        });
    }
    for (auto& worker : workers)
    {
        worker.join();
    }

    double total_damage = 0.0;
    std::uint64_t total_hits = 0;
    std::size_t buckets = 0;
    for (;;)
    {
        std::vector<std::pair<boss_dps::DamageKey, boss_dps::DamageTotal>> batch;
        {
            std::scoped_lock lock{collector_mutex};
            batch = collector.drain(3);
        }
        if (batch.empty())
        {
            break;
        }
        buckets += batch.size();
        for (const auto& [key, total] : batch)
        {
            (void)key;
            total_damage += total.damage;
            total_hits += total.hits;
        }
    }

    const auto expected_hits = thread_count * hits_per_thread;
    const auto expected_damage = static_cast<double>(expected_hits) * damage_per_hit;
    assert(total_hits == expected_hits);
    assert(std::abs(total_damage - expected_damage) < 0.001);
    assert(buckets == thread_count);
    assert(collector.size() == 0);

    const auto elapsed = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - started
    ).count();
    std::cout << "PASS: " << total_hits << " hits -> " << buckets
              << " buckets, exact damage=" << total_damage
              << ", elapsed=" << elapsed << "s\n";
    return 0;
}
