export async function up(queryInterface, Sequelize) {
  await queryInterface.createTable("drivers", {
    id: {
      type: Sequelize.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    user_id: {
      type: Sequelize.INTEGER,
      allowNull: false,
      unique: true,
      references: { model: "users", key: "id" },
    },
    car_model: { type: Sequelize.STRING, allowNull: false },
    plate: { type: Sequelize.STRING, allowNull: false },
    license_no: { type: Sequelize.STRING, allowNull: false },
    verified: {
      type: Sequelize.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    online: {
      type: Sequelize.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    price_per_km: { type: Sequelize.DECIMAL(6, 2), allowNull: false },
    lat: { type: Sequelize.DECIMAL(10, 7), allowNull: true },
    lng: { type: Sequelize.DECIMAL(10, 7), allowNull: true },
    updated_at: { type: Sequelize.DATE, allowNull: false },
  });
}

export async function down(queryInterface) {
  await queryInterface.dropTable("drivers");
}
