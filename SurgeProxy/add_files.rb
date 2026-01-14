require 'xcodeproj'

project_path = 'SurgeProxy.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

puts "Target: #{target.name}"

surge_group = project.main_group['SurgeProxy']
unless surge_group
    puts "SurgeProxy group not found"
    exit 1
end

# Models
models_group = surge_group['Models']
unless models_group
    models_group = surge_group.new_group('Models', 'Models')
end

# Views
views_group = surge_group['Views']
unless views_group
    views_group = surge_group.new_group('Views', 'Views')
end

# Files to add
files_to_add = [
    { group: models_group, file: 'CaptureRequest.swift' },
    { group: models_group, file: 'ConnectionInfo.swift' },
    { group: views_group, file: 'ConnectionsView.swift' },
    { group: views_group, file: 'RuleMatchView.swift' },
    { group: views_group, file: 'DNSLookupView.swift' },
    { group: views_group, file: 'ConnectionDetailView.swift' }
]

files_to_add.each do |item|
  group = item[:group]
  file = item[:file]
  
  puts "Processing #{file} in group #{group.name}..."
  
  file_ref = group.files.find { |f| f.path == file }
  
  unless file_ref
    puts "Adding file reference to group..."
    file_ref = group.new_file(file)
  else
    puts "File reference exists."
  end
  
  if target.source_build_phase.files_references.include?(file_ref)
    puts "File already in build phase."
  else
    puts "Adding file to build phase..."
    target.add_file_references([file_ref])
  end
end

project.save
puts "Project saved successfully."
