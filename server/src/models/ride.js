import { DataTypes } from "sequelize";
import { sequelize } from "../config/db.js";

// fare is a reserved column — NEVER set it (negotiated offline, ARCHITECTURE §9).
export const Ride = sequelize.define(
  "Ride",
  {
    customer_id: { type: DataTypes.INTEGER, allowNull: false },
    driver_id: { type: DataTypes.INTEGER, allowNull: false },
    status: {
      type: DataTypes.ENUM(
        "requested",
        "accepted",
        "declined",
        "en_route",
        "in_progress",
        "completed",
        "cancelled",
      ),
      allowNull: false,
      defaultValue: "requested",
    },
    pickup_lat: { type: DataTypes.DECIMAL(10, 7), allowNull: false },
    pickup_lng: { type: DataTypes.DECIMAL(10, 7), allowNull: false },
    pickup_address: { type: DataTypes.STRING, allowNull: false },
    dropoff_lat: { type: DataTypes.DECIMAL(10, 7), allowNull: false },
    dropoff_lng: { type: DataTypes.DECIMAL(10, 7), allowNull: false },
    dropoff_address: { type: DataTypes.STRING, allowNull: false },
    fare: { type: DataTypes.DECIMAL(8, 2), allowNull: true },
    customer_rating: { type: DataTypes.TINYINT, allowNull: true },
    driver_rating: { type: DataTypes.TINYINT, allowNull: true },
  },
  {
    tableName: "rides",
    underscored: true, // created_at / updated_at
  },
);
