#!/usr/bin/env ruby

# Simple script to add files to Xcode project
require 'fileutils'

project_path = "MixDoctor.xcodeproj/project.pbxproj"
files_to_add = [
  "Core/Services/AudioAnalysisService.swift",
  "Core/Services/AudioFeatureExtractor.swift",
  "Core/Services/AudioProcessor.swift",
  "Core/Models/AnalysisResult.swift",
  "Core/Utilities/Constants.swift",
  "Features/Analysis/CoreML/Models/FrequencyBalanceAnalyzer.swift",
  "Features/Analysis/CoreML/Models/PhaseProblemDetector.swift",
  "Features/Analysis/CoreML/Models/StereoWidthClassifier.swift"
]

puts "Files that need to be added to Xcode project:"
files_to_add.each do |file|
  full_path = File.join(Dir.pwd, file)
  if File.exist?(full_path)
    puts "  ✓ #{file}"
  else
    puts "  ✗ #{file} (NOT FOUND)"
  end
end

puts "\nPlease add these files manually in Xcode:"
puts "1. Open Xcode"
puts "2. Right-click on the project in Project Navigator"
puts "3. Select 'Add Files to MixDoctor...'"
puts "4. Add each file with 'Copy items if needed' UNCHECKED"
puts "5. Make sure 'MixDoctor' target is selected"
