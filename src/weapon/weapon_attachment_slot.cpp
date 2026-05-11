#include "weapon_attachment_slot.h"

WeaponAttachmentSlot::WeaponAttachmentSlot(AttachmentType type)
	: slot_type(type), is_empty(true) {
}

bool WeaponAttachmentSlot::mount_attachment(const Attachment& attachment) {
	if (attachment.type != slot_type) {
		return false; // incompatible type
	}
	equipped = attachment;
	is_empty = false;
	return true;
}

bool WeaponAttachmentSlot::unmount_attachment() {
	equipped = Attachment(); // reset to default
	is_empty = true;
	return true;
}

const Attachment& WeaponAttachmentSlot::get_equipped() const {
	return equipped;
}

bool WeaponAttachmentSlot::is_empty_slot() const {
	return is_empty;
}

float WeaponAttachmentSlot::get_accuracy_bonus() const {
	return is_empty ? 1.0f : equipped.accuracy_bonus;
}

float WeaponAttachmentSlot::get_handling_bonus() const {
	return is_empty ? 1.0f : equipped.handling_bonus;
}

float WeaponAttachmentSlot::get_range_bonus() const {
	return is_empty ? 1.0f : equipped.range_bonus;
}

float WeaponAttachmentSlot::get_recoil_mult() const {
	return is_empty ? 1.0f : equipped.recoil_mult;
}
