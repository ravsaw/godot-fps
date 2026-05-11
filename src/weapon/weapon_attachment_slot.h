#ifndef WEAPON_ATTACHMENT_SLOT_H
#define WEAPON_ATTACHMENT_SLOT_H

#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/core/math_defs.hpp>
#include <godot_cpp/variant/string.hpp>

using namespace godot;

// Attachment type enum
enum class AttachmentType {
	BARREL,
	RAIL,
	STOCK,
	SIGHT,
};

// Attachment data (non-Godot class, just a data container)
struct Attachment {
	AttachmentType type;
	String name;
	float accuracy_bonus;     // +/- accuracy multiplier (1.0 = no change)
	float handling_bonus;     // +/- handling speed multiplier
	float range_bonus;        // +/- effective range multiplier
	float recoil_mult;        // recoil multiplier (0.8 = 20% less recoil)

	Attachment()
		: type(AttachmentType::BARREL), name("None"),
		  accuracy_bonus(1.0f), handling_bonus(1.0f), range_bonus(1.0f), recoil_mult(1.0f) {}

	Attachment(AttachmentType t, const String& n, float acc, float hand, float rng, float rec)
		: type(t), name(n), accuracy_bonus(acc), handling_bonus(hand), range_bonus(rng), recoil_mult(rec) {}
};

// Weapon attachment slot (holds one attachment per slot type)
class WeaponAttachmentSlot {
public:
	AttachmentType slot_type;
	Attachment equipped;
	bool is_empty;

	WeaponAttachmentSlot(AttachmentType type = AttachmentType::BARREL);

	// Mount/unmount attachment
	bool mount_attachment(const Attachment& attachment);
	bool unmount_attachment();

	// Query
	const Attachment& get_equipped() const;
	bool is_empty_slot() const;

	// Stat aggregation
	float get_accuracy_bonus() const;
	float get_handling_bonus() const;
	float get_range_bonus() const;
	float get_recoil_mult() const;
};

#endif // WEAPON_ATTACHMENT_SLOT_H
