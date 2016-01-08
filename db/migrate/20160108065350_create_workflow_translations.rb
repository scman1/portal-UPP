class CreateWorkflowTranslations < ActiveRecord::Migration
  def up
    Workflow.create_translation_table!({
      title: :string,
      description: :text
    }, {
      migrate_data: true
    })
  end

  def down
    Workflow.drop_translation_table! migrate_data: true
  end
end
