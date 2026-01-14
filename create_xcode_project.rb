#!/usr/bin/env ruby

# Script to create a valid Xcode project programmatically

require 'fileutils'
require 'securerandom'

PROJECT_NAME = "SurgeProxy"
PROJECT_DIR = File.expand_path("SurgeProxy", __dir__)
XCODEPROJ_DIR = File.join(PROJECT_DIR, "#{PROJECT_NAME}.xcodeproj")

# Generate UUIDs
def uuid
  SecureRandom.uuid.gsub('-', '').upcase[0..23]
end

# Collect all Swift files
swift_files = []
Dir.glob(File.join(PROJECT_DIR, "**/*.swift")).each do |file|
  relative_path = file.sub(PROJECT_DIR + "/", "")
  swift_files << relative_path
end

puts "Found #{swift_files.length} Swift files"

# Create project directory
FileUtils.mkdir_p(XCODEPROJ_DIR)

# Generate project.pbxproj
project_content = <<~PBXPROJ
// !$*UTF8*$!
{
\tarchiveVersion = 1;
\tclasses = {
\t};
\tobjectVersion = 56;
\tobjects = {
\t\t/* Begin PBXBuildFile section */
PBXPROJ

# Add build files
build_file_refs = {}
swift_files.each_with_index do |file, i|
  file_uuid = uuid
  build_uuid = uuid
  build_file_refs[file] = { file: file_uuid, build: build_uuid }
  basename = File.basename(file)
  project_content += "\t\t#{build_uuid} /* #{basename} in Sources */ = {isa = PBXBuildFile; fileRef = #{file_uuid} /* #{basename} */; };\n"
end

# Assets
assets_uuid = uuid
assets_build_uuid = uuid
project_content += "\t\t#{assets_build_uuid} /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = #{assets_uuid} /* Assets.xcassets */; };\n"

project_content += "\t\t/* End PBXBuildFile section */\n\n"

# File references
project_content += "\t\t/* Begin PBXFileReference section */\n"
app_uuid = uuid
project_content += "\t\t#{app_uuid} /* #{PROJECT_NAME}.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = #{PROJECT_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; };\n"

swift_files.each do |file|
  basename = File.basename(file)
  file_uuid = build_file_refs[file][:file]
  project_content += "\t\t#{file_uuid} /* #{basename} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"#{file}\"; sourceTree = \"<group>\"; };\n"
end

project_content += "\t\t#{assets_uuid} /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; };\n"
info_plist_uuid = uuid
project_content += "\t\t#{info_plist_uuid} /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; };\n"
project_content += "\t\t/* End PBXFileReference section */\n\n"

# Frameworks
frameworks_uuid = uuid
project_content += "\t\t/* Begin PBXFrameworksBuildPhase section */\n"
project_content += "\t\t#{frameworks_uuid} /* Frameworks */ = {\n"
project_content += "\t\t\tisa = PBXFrameworksBuildPhase;\n"
project_content += "\t\t\tbuildActionMask = 2147483647;\n"
project_content += "\t\t\tfiles = (\n"
project_content += "\t\t\t);\n"
project_content += "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
project_content += "\t\t};\n"
project_content += "\t\t/* End PBXFrameworksBuildPhase section */\n\n"

# Groups
project_content += "\t\t/* Begin PBXGroup section */\n"
main_group_uuid = uuid
products_group_uuid = uuid
source_group_uuid = uuid

project_content += "\t\t#{main_group_uuid} = {\n"
project_content += "\t\t\tisa = PBXGroup;\n"
project_content += "\t\t\tchildren = (\n"
project_content += "\t\t\t\t#{source_group_uuid} /* #{PROJECT_NAME} */,\n"
project_content += "\t\t\t\t#{products_group_uuid} /* Products */,\n"
project_content += "\t\t\t);\n"
project_content += "\t\t\tsourceTree = \"<group>\";\n"
project_content += "\t\t};\n"

project_content += "\t\t#{products_group_uuid} /* Products */ = {\n"
project_content += "\t\t\tisa = PBXGroup;\n"
project_content += "\t\t\tchildren = (\n"
project_content += "\t\t\t\t#{app_uuid} /* #{PROJECT_NAME}.app */,\n"
project_content += "\t\t\t);\n"
project_content += "\t\t\tname = Products;\n"
project_content += "\t\t\tsourceTree = \"<group>\";\n"
project_content += "\t\t};\n"

project_content += "\t\t#{source_group_uuid} /* #{PROJECT_NAME} */ = {\n"
project_content += "\t\t\tisa = PBXGroup;\n"
project_content += "\t\t\tchildren = (\n"
swift_files.each do |file|
  basename = File.basename(file)
  file_uuid = build_file_refs[file][:file]
  project_content += "\t\t\t\t#{file_uuid} /* #{basename} */,\n"
end
project_content += "\t\t\t\t#{assets_uuid} /* Assets.xcassets */,\n"
project_content += "\t\t\t\t#{info_plist_uuid} /* Info.plist */,\n"
project_content += "\t\t\t);\n"
project_content += "\t\t\tpath = #{PROJECT_NAME};\n"
project_content += "\t\t\tsourceTree = \"<group>\";\n"
project_content += "\t\t};\n"
project_content += "\t\t/* End PBXGroup section */\n\n"

# Native target
target_uuid = uuid
project_content += "\t\t/* Begin PBXNativeTarget section */\n"
project_content += "\t\t#{target_uuid} /* #{PROJECT_NAME} */ = {\n"
project_content += "\t\t\tisa = PBXNativeTarget;\n"
build_config_list_uuid = uuid
project_content += "\t\t\tbuildConfigurationList = #{build_config_list_uuid} /* Build configuration list for PBXNativeTarget \"#{PROJECT_NAME}\" */;\n"
sources_uuid = uuid
resources_uuid = uuid
project_content += "\t\t\tbuildPhases = (\n"
project_content += "\t\t\t\t#{sources_uuid} /* Sources */,\n"
project_content += "\t\t\t\t#{frameworks_uuid} /* Frameworks */,\n"
project_content += "\t\t\t\t#{resources_uuid} /* Resources */,\n"
project_content += "\t\t\t);\n"
project_content += "\t\t\tbuildRules = (\n"
project_content += "\t\t\t);\n"
project_content += "\t\t\tdependencies = (\n"
project_content += "\t\t\t);\n"
project_content += "\t\t\tname = #{PROJECT_NAME};\n"
project_content += "\t\t\tproductName = #{PROJECT_NAME};\n"
project_content += "\t\t\tproductReference = #{app_uuid} /* #{PROJECT_NAME}.app */;\n"
project_content += "\t\t\tproductType = \"com.apple.product-type.application\";\n"
project_content += "\t\t};\n"
project_content += "\t\t/* End PBXNativeTarget section */\n\n"

# Project
project_uuid = uuid
project_build_config_list_uuid = uuid
project_content += "\t\t/* Begin PBXProject section */\n"
project_content += "\t\t#{project_uuid} /* Project object */ = {\n"
project_content += "\t\t\tisa = PBXProject;\n"
project_content += "\t\t\tattributes = {\n"
project_content += "\t\t\t\tBuildIndependentTargetsInParallel = 1;\n"
project_content += "\t\t\t\tLastSwiftUpdateCheck = 1500;\n"
project_content += "\t\t\t\tLastUpgradeCheck = 1500;\n"
project_content += "\t\t\t};\n"
project_content += "\t\t\tbuildConfigurationList = #{project_build_config_list_uuid} /* Build configuration list for PBXProject \"#{PROJECT_NAME}\" */;\n"
project_content += "\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n"
project_content += "\t\t\tdevelopmentRegion = en;\n"
project_content += "\t\t\thasScannedForEncodings = 0;\n"
project_content += "\t\t\tknownRegions = (\n"
project_content += "\t\t\t\ten,\n"
project_content += "\t\t\t\tBase,\n"
project_content += "\t\t\t);\n"
project_content += "\t\t\tmainGroup = #{main_group_uuid};\n"
project_content += "\t\t\tproductRefGroup = #{products_group_uuid} /* Products */;\n"
project_content += "\t\t\tprojectDirPath = \"\";\n"
project_content += "\t\t\tprojectRoot = \"\";\n"
project_content += "\t\t\ttargets = (\n"
project_content += "\t\t\t\t#{target_uuid} /* #{PROJECT_NAME} */,\n"
project_content += "\t\t\t);\n"
project_content += "\t\t};\n"
project_content += "\t\t/* End PBXProject section */\n\n"

# Resources
project_content += "\t\t/* Begin PBXResourcesBuildPhase section */\n"
project_content += "\t\t#{resources_uuid} /* Resources */ = {\n"
project_content += "\t\t\tisa = PBXResourcesBuildPhase;\n"
project_content += "\t\t\tbuildActionMask = 2147483647;\n"
project_content += "\t\t\tfiles = (\n"
project_content += "\t\t\t\t#{assets_build_uuid} /* Assets.xcassets in Resources */,\n"
project_content += "\t\t\t);\n"
project_content += "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
project_content += "\t\t};\n"
project_content += "\t\t/* End PBXResourcesBuildPhase section */\n\n"

# Sources
project_content += "\t\t/* Begin PBXSourcesBuildPhase section */\n"
project_content += "\t\t#{sources_uuid} /* Sources */ = {\n"
project_content += "\t\t\tisa = PBXSourcesBuildPhase;\n"
project_content += "\t\t\tbuildActionMask = 2147483647;\n"
project_content += "\t\t\tfiles = (\n"
swift_files.each do |file|
  basename = File.basename(file)
  build_uuid = build_file_refs[file][:build]
  project_content += "\t\t\t\t#{build_uuid} /* #{basename} in Sources */,\n"
end
project_content += "\t\t\t);\n"
project_content += "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
project_content += "\t\t};\n"
project_content += "\t\t/* End PBXSourcesBuildPhase section */\n\n"

# Build configurations
debug_uuid = uuid
release_uuid = uuid
project_content += "\t\t/* Begin XCBuildConfiguration section */\n"
project_content += "\t\t#{debug_uuid} /* Debug */ = {\n"
project_content += "\t\t\tisa = XCBuildConfiguration;\n"
project_content += "\t\t\tbuildSettings = {\n"
project_content += "\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";\n"
project_content += "\t\t\t\tSWIFT_VERSION = 5.0;\n"
project_content += "\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.0;\n"
project_content += "\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.surgeproxy.app;\n"
project_content += "\t\t\t\tINFOPLIST_FILE = SurgeProxy/Info.plist;\n"
project_content += "\t\t\t\tENABLE_PREVIEWS = YES;\n"
project_content += "\t\t\t\tCODE_SIGN_IDENTITY = \"-\";\n"
project_content += "\t\t\t};\n"
project_content += "\t\t\tname = Debug;\n"
project_content += "\t\t};\n"
project_content += "\t\t#{release_uuid} /* Release */ = {\n"
project_content += "\t\t\tisa = XCBuildConfiguration;\n"
project_content += "\t\t\tbuildSettings = {\n"
project_content += "\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";\n"
project_content += "\t\t\t\tSWIFT_VERSION = 5.0;\n"
project_content += "\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.0;\n"
project_content += "\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.surgeproxy.app;\n"
project_content += "\t\t\t\tINFOPLIST_FILE = SurgeProxy/Info.plist;\n"
project_content += "\t\t\t\tENABLE_PREVIEWS = YES;\n"
project_content += "\t\t\t\tCODE_SIGN_IDENTITY = \"-\";\n"
project_content += "\t\t\t};\n"
project_content += "\t\t\tname = Release;\n"
project_content += "\t\t};\n"
project_content += "\t\t/* End XCBuildConfiguration section */\n\n"

# Configuration lists
project_content += "\t\t/* Begin XCConfigurationList section */\n"
project_content += "\t\t#{build_config_list_uuid} /* Build configuration list for PBXNativeTarget \"#{PROJECT_NAME}\" */ = {\n"
project_content += "\t\t\tisa = XCConfigurationList;\n"
project_content += "\t\t\tbuildConfigurations = (\n"
project_content += "\t\t\t\t#{debug_uuid} /* Debug */,\n"
project_content += "\t\t\t\t#{release_uuid} /* Release */,\n"
project_content += "\t\t\t);\n"
project_content += "\t\t\tdefaultConfigurationIsVisible = 0;\n"
project_content += "\t\t\tdefaultConfigurationName = Release;\n"
project_content += "\t\t};\n"
project_content += "\t\t#{project_build_config_list_uuid} /* Build configuration list for PBXProject \"#{PROJECT_NAME}\" */ = {\n"
project_content += "\t\t\tisa = XCConfigurationList;\n"
project_content += "\t\t\tbuildConfigurations = (\n"
project_content += "\t\t\t\t#{debug_uuid} /* Debug */,\n"
project_content += "\t\t\t\t#{release_uuid} /* Release */,\n"
project_content += "\t\t\t);\n"
project_content += "\t\t\tdefaultConfigurationIsVisible = 0;\n"
project_content += "\t\t\tdefaultConfigurationName = Release;\n"
project_content += "\t\t};\n"
project_content += "\t\t/* End XCConfigurationList section */\n"

project_content += "\t};\n"
project_content += "\trootObject = #{project_uuid} /* Project object */;\n"
project_content += "}\n"

# Write project file
project_file = File.join(XCODEPROJ_DIR, "project.pbxproj")
File.write(project_file, project_content)

puts "✅ Created #{project_file}"
puts "🎉 Xcode project created successfully!"
puts ""
puts "Opening Xcode..."
system("open #{XCODEPROJ_DIR}")
