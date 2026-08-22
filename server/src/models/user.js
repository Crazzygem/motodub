import { DataTypes } from "sequelize";
import { sequelize } from "../config/db.js";

export const User = sequelize.define(
  "User",
  {
    role: {
      type: DataTypes.ENUM("customer", "driver", "admin"),
      allowNull: false,
    },
    name: { type: DataTypes.STRING, allowNull: false },
    phone: { type: DataTypes.STRING, allowNull: false },
    email: { type: DataTypes.STRING, allowNull: false, unique: true },
    password_hash: { type: DataTypes.STRING, allowNull: false },
    photo: { type: DataTypes.STRING, allowNull: true },
    rating: {
      type: DataTypes.DECIMAL(2, 1),
      allowNull: false,
      defaultValue: 5.0,
    },
    active: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
    fcm_token: { type: DataTypes.STRING, allowNull: true },
  },
  {
    tableName: "users",
    underscored: true, // created_at / updated_at
  },
);
