require 'nokogiri'
require 'open-uri'
require 'wunderground'

class TFS
  include HTTParty

  base_uri 'http://ags1.dtsgis.com/ArcGIS/rest/services/v2'

  def self.risk_assessment(latlon)
    response = get('/RiskAssessment/MapServer/identify',
      :query => {
        :geometryType => "esriGeometryPoint",
        :geometry => "{x: " + latlon.x.to_s + ", y: " + latlon.y.to_s + "}",
        :sr => 4326,
        :layers => 'all',
        :tolerance => 3,
        :mapExtent => '-98,30,-97,31',
        :imageDisplay => '572,740,96',
        :returnGeometry => true,
        :f => 'pjson'
      }
    )
    json_response = JSON.parse(response.body)
    return json_response['results'][0]['attributes']['Pixel Value'].to_i
  end
end

class CartoDB
  include HTTParty

  base_uri 'http://tinio.cartodb.com/api/v2'

  def self.current_county(latlon)
    response = get('/sql',
      :query => {
        :q => "SELECT name FROM cntys04 ORDER BY ST_Distance(ST_GeomFromText('POINT(" + latlon.x.to_s + " " + latlon.y.to_s + ")',4326), the_geom) LIMIT 1;"
      }
    )
    json_response = JSON.parse(response.body)
    return json_response['rows'][0]['name']
  end
end

class MapController < ApplicationController
  def get
  end

  def post
    address_str = params[:q]
    coordinates = Geocoder.coordinates(address_str)
    @address = Address.create(:address => address_str, :latlon => 'POINT(' + coordinates[1].to_s + ' ' + coordinates[0].to_s + ')')

    # Closest Fire Station
    @cfs = FireStation.order("ST_Distance(latlon, '" + @address.latlon.to_s + "') LIMIT 1")[0]
    @distance = "%.02f" % @address.latlon.distance(@cfs.latlon)

    # Weather Conditions
    w_api = Wunderground.new(ENV['WUNDERGROUND_API_KEY'])
    w_response = w_api.get_conditions_for(@address.latlon.y.to_s + "," + @address.latlon.x.to_s)
    @wind_conditions = w_response['current_observation']['wind_string']
    @relative_humidity = w_response['current_observation']['relative_humidity']

    # Counties with a Burn Ban
    rss = Nokogiri::XML(open('http://tfsfrp.tamu.edu/wildfires/BurnBan.xml'))
    rss.encoding = 'utf-8'
    counties_text = rss.css('rss channel item description').text
    counties_array = counties_text.strip.split(', ')
    @counties_list = '\'' + counties_array.join("\', \'") + '\''
    @inside_burnban = counties_array.include?(CartoDB.current_county(@address.latlon))

    # Risk Assessment Level
    @risk_level = TFS.risk_assessment(@address.latlon)

  end
end
