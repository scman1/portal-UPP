#encoding: utf-8
# Seeds the database with BioVeL-specific data

# Seeds projects
biovel = Project.find_by_title('BioVeL') || Project.create(:title => 'BioVeL')
puts 'Seeded the BioVeL project.'

# Seeds institutions
institutions = [
  {:title => 'University of Manchester', :country => 'United Kingdom'},
  {:title => 'Cardiff University', :country => 'United Kingdom'},
  {:title => 'Centro de Referência em Informação Ambiental', :country => 'Brazil'},
  {:title => 'Foundation for Research on Biodiversity', :country => 'France'},
  {:title => 'Fraunhofer-Gesellschaft Institute IAIS', :country => 'Germany'},
  {:title => 'Berlin Botanical Gardens and Botanical Museum', :country => 'Germany'},
  {:title => 'Hungarian Academy of Sciences Institute of Ecology and Botany', :country => 'Hungary'},
  {:title => 'Max Planck Society, MPI for Marine Microbiology', :country => 'Germany'},
  {:title => 'National Institute of Nuclear Physics', :country => 'Italy'},
  {:title => 'National Research Council: Institute for Biomedical Technologies and Institute of Biomembrane and Bioenergetics', :country => 'Italy'},
  {:title => 'Netherlands Centre for Biodiversity ', :country => 'Netherlands'},
  {:title => 'Stichting European Grid Initiative', :country => 'Netherlands'},
  {:title => 'University of Amsterdam', :country => 'Netherlands'},
  {:title => 'University of Eastern Finland', :country => 'Finland'},
  {:title => 'University of Gothenburg', :country => 'Sweden'}
]

count = 0
institutions.each do |inst|
  institution = Institution.where(:title => inst[:title], :country => inst[:country]).first ||
                Institution.create(:title => inst[:title], :country => inst[:country])
  unless WorkGroup.where(:project_id => biovel.id, :institution_id => institution.id).exists?
    WorkGroup.create(:project_id => biovel.id, :institution_id => institution.id)
    count += 1
  end
end

puts "Seeded #{count} BioVeL project's institutions."

# Seeds workflow categories
workflow_categories = [WorkflowCategory::TAXONOMIC_REFINEMENT, WorkflowCategory::ENM, WorkflowCategory::METAGENOMICS,
                       WorkflowCategory::PHYLOGENETICS, WorkflowCategory::POPULATION_MODELLING, WorkflowCategory::ECOSYSTEM_MODELLING,
                       WorkflowCategory::OTHER]

count = 0
workflow_categories.each do |category|
  unless WorkflowCategory.find_by_name(category)
    WorkflowCategory.create!(name: category)
    count += 1
  end
end

puts "Seeded #{count} workflow categories."

# Seeds workflow input port types
workflow_input_port_types = [WorkflowInputPortType::DATA, WorkflowInputPortType::PARAMETER]

count = 0
workflow_input_port_types.each do |type|
  unless WorkflowInputPortType.find_by_name(type)
    WorkflowInputPortType.create!(name: type)
    count += 1
  end
end

puts "Seeded #{count} workflow input port types."

# Seeds workflow output port types
workflow_output_port_types = [WorkflowOutputPortType::RESULT, WorkflowOutputPortType::ERROR_LOG]
count = 0
workflow_output_port_types.each do |type|
  unless WorkflowOutputPortType.find_by_name(type)
    WorkflowOutputPortType.create!(name: type)
    count += 1
  end
end

puts "Seeded #{count} workflow output port types."

# Admin User
admin_inst = {:title => 'University of Manchester', :country => 'United Kingdom'}

admin_institution = Institution.where(:title => admin_inst[:title], :country => admin_inst[:country]).first ||
    Institution.create(:title => admin_inst[:title], :country => admin_inst[:country])

admin_workgroup = WorkGroup.where(:project_id => biovel.id, :institution_id => admin_institution.id).first ||
    WorkGroup.create(:project_id => biovel.id, :institution_id => admin_institution.id)

admin_user = User.find_by_login('{{biovel_portal_admin_user}}') ||
    User.create(:login => '{{biovel_portal_admin_user}}', :email => '{{biovel_portal_admin_email}}',
     :password => '{{biovel_portal_admin_pass}}', :password_confirmation => '{{biovel_portal_admin_pass}}')

admin_user.activate
admin_user.person ||= Person.create(:first_name => 'Admin', :last_name => 'User', :email => '{{biovel_portal_admin_email}}')
admin_user.save
admin_user.person.work_groups << admin_workgroup
admin_person = admin_user.person
admin_person.add_roles([['gatekeeper', biovel],
                        ['project_manager', biovel]])
admin_person.save

puts 'Seeded the Admin user.'

# Guest User
guest_project = Project.find_by_title('BioVeL Portal Guests') || Project.create(:title => 'BioVeL Portal Guests')

guest_inst = {:title => 'Example Institution', :country => 'United Kingdom'}

guest_institution = Institution.where(:title => guest_inst[:title], :country => guest_inst[:country]).first ||
    Institution.create(:title => guest_inst[:title], :country => guest_inst[:country])

guest_workgroup = WorkGroup.where(:project_id => guest_project.id, :institution_id => guest_institution.id).first ||
    WorkGroup.create(:project_id => guest_project.id, :institution_id => guest_institution.id)

# Portal requires unique email addresses, so guest email address must be
# different to admin email address
guest_user = User.find_by_login('guest') ||
    User.create(:login => 'guest', :email => 'guest@example.com',
      :password => 'guest', :password_confirmation => 'guest')

guest_user.activate
guest_user.person ||= Person.create(:first_name => 'Guest', :last_name => 'User', :email => 'guest@example.com')
guest_user.save
guest_user.person.work_groups << guest_workgroup
puts 'Seeded the Guest user.'

{% if rserve_users is defined %}
TavernaPlayer::ServiceCredential.create(
  :name => 'R Server on localhost',
  :description => 'R Server',
  :uri => 'rserve://localhost:6311',
  :login => '{{rserve_users[0]["user"]}}',
  :password => '{{rserve_users[0]["pass"]}}',
  :password_confirmation => '{{rserve_users[0]["pass"]}}'
)
puts 'Seeded the R server credential'
{% endif %}

puts "Done."

