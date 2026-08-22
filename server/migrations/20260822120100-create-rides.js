export async function up(queryInterface, Sequelize) {
  await queryInterface.createTable("rides", {
    id: {
      type: Sequelize.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    customer_id: {
      type: Sequelize.INTEGER,
      allowNull: false,
      references: { model: "users", key: "id" },
    },
    driver_id: {
      type: Sequelize.INTEGER,
      allowNull: false,
      references: { model: "users", key: "id" },
    },
    status: {
      type: Sequelize.ENUM(
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
    pickup_lat: { type: Sequelize.DECIMAL(10, 7), allowNull: false },
    pickup_lng: { type: Sequelize.DECIMAL(10, 7), allowNull: false },
    pickup_address: { type: Sequelize.STRING, allowNull: false },
    dropoff_lat: { type: Sequelize.DECIMAL(10, 7), allowNull: false },
    dropoff_lng: { type: Sequelize.DECIMAL(10, 7), allowNull: false },
    dropoff_address: { type: Sequelize.STRING, allowNull: false },
    fare: { type: Sequelize.DECIMAL(8, 2), allowNull: true },
    customer_rating: { type: Sequelize.TINYINT, allowNull: true },
    driver_rating: { type: Sequelize.TINYINT, allowNull: true },
    created_at: { type: Sequelize.DATE, allowNull: false },
    updated_at: { type: Sequelize.DATE, allowNull: false },
  });

  await queryInterface.addIndex("rides", ["status"]);
  await queryInterface.addIndex("rides", ["driver_id"]);
  await queryInterface.addIndex("rides", ["customer_id"]);
}

export async function down(queryInterface) {
  await queryInterface.removeIndex("rides", ["status"]);
  await queryInterface.removeIndex("rides", ["driver_id"]);
  await queryInterface.removeIndex("rides", ["customer_id"]);
  await queryInterface.dropTable("rides");
}
