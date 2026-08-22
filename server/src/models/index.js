import { User } from "./user.js";
import { Driver } from "./driver.js";
import { Ride } from "./ride.js";

Driver.belongsTo(User, { foreignKey: { name: "user_id", allowNull: false } });
Ride.belongsTo(User, {
  as: "customer",
  foreignKey: { name: "customer_id", allowNull: false },
});
Ride.belongsTo(User, {
  as: "driver",
  foreignKey: { name: "driver_id", allowNull: false },
});

export { User, Driver, Ride };
