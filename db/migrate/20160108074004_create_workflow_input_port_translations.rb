class CreateWorkflowInputPortTranslations < ActiveRecord::Migration
  def up
    WorkflowInputPort.create_translation_table!({
      name: :string,
      description: :text
    }, {
      migrate_data: true
    })
  end

  def down
    WorkflowInputPort.drop_translation_table! migrate_data: true
  end
end
