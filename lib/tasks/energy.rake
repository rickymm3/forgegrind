namespace :energy do
  desc "Perform one tick of energy for all users"
  task tick: :environment do
    puts "[#{Time.now}] Performing energy tick..."
    EnergyTickJob.perform_now
  end
end
