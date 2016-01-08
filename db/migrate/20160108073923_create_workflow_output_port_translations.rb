class CreateWorkflowOutputPortTranslations < ActiveRecord::Migration
  def up
    WorkflowOutputPort.create_translation_table!({
      name: :string,
      description: :text
    }, {
      migrate_data: true
    })
  end

  def down
    WorkflowOutputPort.drop_translation_table! migrate_data: true
  end
end
