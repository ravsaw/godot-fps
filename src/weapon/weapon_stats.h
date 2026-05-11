#ifndef WEAPON_STATS_H
#define WEAPON_STATS_H

#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/core/math_defs.hpp>

using namespace godot;

class WeaponStats {
public:
	// Durability system
	static constexpr float MAX_DURABILITY = 100.0f;
	static constexpr float DURABILITY_PER_SHOT = 0.5f; // loss per projectile fired

	// Accuracy degradation curve
	static constexpr float ACCURACY_PENALTY_AT_HALF_WEAR = 0.85f; // at 50% durability, accuracy = 0.85
	static constexpr float ACCURACY_PENALTY_AT_FULL_WEAR = 0.60f; // at 0% durability, accuracy = 0.60

	// Reliability (jam chance)
	static constexpr float RELIABILITY_AT_HALF_WEAR = 0.98f; // 2% jam chance at 50% wear
	static constexpr float RELIABILITY_AT_FULL_WEAR = 0.80f; // 20% jam chance at 0% wear

	float durability;

	WeaponStats();

	// Durability management
	void fire_shot(); // decrements durability by DURABILITY_PER_SHOT
	void repair(float amount); // restore durability (capped at MAX)
	float get_durability_percent() const;

	// Stat multipliers (0.0 to 1.0, used as accuracy_mult or reliability_percent)
	float get_accuracy_multiplier() const;
	float get_reliability_percent() const;

	// Check if weapon jams (random based on reliability)
	bool check_jam();

	// Reset
	void reset_to_new();
};

#endif // WEAPON_STATS_H
