#pragma once

#include <cstddef>
#include <cstdint>
#include <unordered_map>
#include <utility>
#include <vector>

namespace boss_dps
{
    struct DamageKey
    {
        std::uintptr_t defender{};
        std::uintptr_t attacker{};
        std::uintptr_t damage_causer{};
        std::uintptr_t override_network_owner{};
        std::uintptr_t info_attacker{};

        auto operator==(const DamageKey&) const -> bool = default;
    };

    struct DamageKeyHash
    {
        auto operator()(const DamageKey& key) const noexcept -> std::size_t
        {
            auto value = static_cast<std::size_t>(key.defender);
            const auto mix = [&value](std::uintptr_t part) {
                value ^= static_cast<std::size_t>(part) + 0x9e3779b97f4a7c15ULL
                    + (value << 6U) + (value >> 2U);
            };
            mix(key.attacker);
            mix(key.damage_causer);
            mix(key.override_network_owner);
            mix(key.info_attacker);
            return value;
        }
    };

    struct DamageTotal
    {
        double damage{};
        std::uint64_t hits{};
    };

    class CollectorCore
    {
      public:
        auto add(const DamageKey& key, double damage) -> bool
        {
            if (damage <= 0.0)
            {
                return false;
            }
            auto& total = m_totals[key];
            total.damage += damage;
            ++total.hits;
            ++m_accepted_hits;
            return true;
        }

        auto drain(std::size_t limit) -> std::vector<std::pair<DamageKey, DamageTotal>>
        {
            std::vector<std::pair<DamageKey, DamageTotal>> result;
            if (limit == 0)
            {
                return result;
            }
            result.reserve(limit < m_totals.size() ? limit : m_totals.size());
            auto iterator = m_totals.begin();
            while (iterator != m_totals.end() && result.size() < limit)
            {
                result.emplace_back(iterator->first, iterator->second);
                iterator = m_totals.erase(iterator);
            }
            m_drained_buckets += result.size();
            return result;
        }

        [[nodiscard]] auto size() const noexcept -> std::size_t
        {
            return m_totals.size();
        }

        [[nodiscard]] auto accepted_hits() const noexcept -> std::uint64_t
        {
            return m_accepted_hits;
        }

        [[nodiscard]] auto drained_buckets() const noexcept -> std::uint64_t
        {
            return m_drained_buckets;
        }

      private:
        std::unordered_map<DamageKey, DamageTotal, DamageKeyHash> m_totals;
        std::uint64_t m_accepted_hits{};
        std::uint64_t m_drained_buckets{};
    };
}
