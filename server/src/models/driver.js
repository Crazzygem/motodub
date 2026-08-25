import { DataTypes } from "sequelize";
import { sequelize } from "../config/db.js";

// One row per driver account (user_id UNIQUE). No created_at by design —
// updated_at is the location heartbeat column (ARCHITECTURE §10).
export const Driver = sequelize.define(
  "Driver",
  {
    user_id: { type: DataTypes.INTEGER, allowNull: false, unique: true },
    car_model: { type: DataTypes.STRING, allowNull: false },
    plate: { type: DataTypes.STRING, allowNull: false },
    license_no: { type: DataTypes.STRING, allowNull: false },
    verified: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
    online: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
    price_per_km: { type: DataTypes.DECIMAL(6, 2), allowNull: false },
    vehicle_photo: { type: DataTypes.STRING(255), allowNull: true },
    lat: { type: DataTypes.DECIMAL(10, 7), allowNull: true },
    lng: { type: DataTypes.DECIMAL(10, 7), allowNull: true },
  },
  {
    tableName: "drivers",
    timestamps: true,
    createdAt: false,
    updatedAt: "updated_at",
  },
);
