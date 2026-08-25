/**
 * Gallery payload helper (multi-photo driver card): drivers.vehicle_photos
 * is the JSON array; rows that predate the column fall back to their single
 * vehicle_photo cover so every card/admin/viewer payload carries an array.
 */
export function vehiclePhotosOf(row) {
  const photos = row?.vehicle_photos;
  if (Array.isArray(photos)) return photos;
  const cover = row?.vehicle_photo;
  return typeof cover === "string" && cover.length > 0 ? [cover] : [];
}
