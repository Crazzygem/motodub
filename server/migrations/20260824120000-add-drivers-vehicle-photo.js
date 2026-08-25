export async function up(queryInterface, Sequelize) {
  await queryInterface.addColumn("drivers", "vehicle_photo", {
    type: Sequelize.STRING(255),
    allowNull: true,
  });
}

export async function down(queryInterface) {
  await queryInterface.removeColumn("drivers", "vehicle_photo");
}
