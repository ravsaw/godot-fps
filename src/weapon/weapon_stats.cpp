#include "weapon_stats.h"
#include <godot_cpp/core/math_defs.hpp>
#include <algorithm>
#include <cstdlib>
#include <cmath>

WeaponStats::WeaponStats() : durability(MAX_DURABILITY) {
}

void WeaponStats::fire_shot() {
	durability = std::max(0.0f, durability - DURABILITY_PER_SHOT);
}

void WeaponStats::repair(float amount) {
	durability = std::min(MAX_DURABILITY, durability + amount);
}

float WeaponStats::get_durability_percent() const {
	return durability / MAX_DURABILITY;
}

float WeaponStats::get_accuracy_multiplier() const {
	float wear_percent = 1.0f - get_durability_percent();
	
	if (wear_percent <= 0.5f) {
		// Linear interpolation from 1.0 (new) to 0.85 (half-worn)
		return 1.0f - (wear_percent / 0.5f) * (1.0f - ACCURACY_PENALTY_AT_HALF_WEAR);
	} else {
		// Linear from 0.85 (half-worn) to 0.60 (fully worn)
		return ACCURACY_PENALTY_AT_HALF_WEAR - ((wear_percent - 0.5f) / 0.5f) * (ACCURACY_PENALTY_AT_HALF_WEAR - ACCURACY_PENALTY_AT_FULL_WEAR);
	}
}

float WeaponStats::get_reliability_percent() const {
	float wear_percent = 1.0f - get_durability_percent();

	if (wear_percent <= 0.5f) {
		// Linear from 1.0 to 0.98 (half-worn)
		return 1.0f - (wear_percent / 0.5f) * (1.0f - RELIABILITY_AT_HALF_WEAR);
	} else {
		// Linear from 0.98 to 0.80 (fully worn)
		return RELIABILITY_AT_HALF_WEAR - ((wear_percent - 0.5f) / 0.5f) * (RELIABILITY_AT_HALF_WEAR - RELIABILITY_AT_FULL_WEAR);
	}
}

bool WeaponStats::check_jam() {
	float reliability = get_reliability_percent();
	float roll = (float)rand() / RAND_MAX;
	return roll > reliability; // true = jam
}

void WeaponStats::reset_to_new() {
	durability = MAX_DURABILITY;
}
