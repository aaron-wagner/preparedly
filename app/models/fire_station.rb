require 'csv'
require 'open-uri'
RGeo::ActiveRecord::GeometryMixin.set_json_generator(:geojson)

class FireStation < ActiveRecord::Base
  attr_accessible :address, :latlon, :zip
  set_rgeo_factory_for_column(:latlon, RGeo::Geographic.spherical_factory(:srid => 4326))

  def self.populate
    csv_text = nil
    # on the CofA Github account under my login - Public GIST
    open('https://gist.githubusercontent.com/aaron-wagner/60ba2b5e9eeab35828a5/raw/76e47ca52136f2d6a88585cf8755e887795ee0ab/afd_stations.csv') do |f|
    #open('https://gist.githubusercontent.com/tinio/2504610/raw/76e47ca52136f2d6a88585cf8755e887795ee0ab/afd_stations.csv') do |f|
      csv_text = f.read()
    end
    logger.info "csv_text:" + csv_text
    csv = CSV.parse(csv_text, :headers => true)
    csv.each do |row|
      fs = FireStation.create
      fs.address = row[2]
      fs.zip = row[5].to_i
      fs.latlon = "POINT(" + row[7] + " " + row[6] +")"
      puts fs.address, fs.zip, fs.latlon
      fs.save!
    end
  end
end
