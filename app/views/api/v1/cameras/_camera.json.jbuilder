camera ||= @camera

json.id camera['id']
json.manufacturer_id camera['manufacturer_id']
json.model camera['model']
json.manual_url camera.documents.first.file.url
json.jpeg_url camera['jpeg_url']
json.h264_url camera['h264_url']
json.mjpeg_url camera['mjpeg_url']
json.resolution camera['resolution']
json.firmware camera['firmware']
json.credentials camera['credentials']
json.shape camera['shape']
json.fov camera['fov']
json.onvif camera['onvif']
json.psia camera['psia']
json.ptz camera['ptz']
json.infrared camera['infrared']
json.varifocal camera['varifocal']
json.sd_card camera['sd_card']
json.upnp camera['upnp']
json.url api_v1_camera_url(camera, format: :json)

if camera.class == ActiveRecord::Base && !camera.persisted? &&
  !camera.valid?
  json.errors camera.errors.messages
end
