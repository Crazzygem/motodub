export async function up(queryInterface, Sequelize) {
  await queryInterface.addColumn("drivers", "vehicle_photos", {
    type: Sequelize.TEXT,
    allowNull: true,
  });
}

export async function down(queryInterface) {
  await queryInterface.removeColumn("drivers", "vehicle_photos");
}
