require_relative 'bsky'
require 'net/http'
require 'uri'
require 'json'
require 'date'
require 'open-uri'
require 'stringio'

animal_types = ["dog", "cat", "bunny", "duck", "lizard"]

def get_animal(animal)
    case animal
    when "dog"
        response = Net::HTTP.get(URI.parse("https://dog.ceo/api/breeds/image/random"))
        return JSON.parse(response)["message"]
    when "cat"
        return "https://cataas.com/cat"
    when "bunny"
        response = Net::HTTP.get(URI.parse("https://api.bunnies.io/v2/loop/random/?media=gif,png"))
        return JSON.parse(response)["media"]["poster"]
    when "duck"
        response = Net::HTTP.get(URI.parse("https://random-d.uk/api/v2/random?type=jpg"))
        return JSON.parse(response)["url"]
    when "lizard"
        response = Net::HTTP.get(URI.parse("https://nekos.life/api/v2/img/lizard"))
        return JSON.parse(response)["url"]
    end
end

def get_image(url)
    begin
        image_data = Net::HTTP.get(URI.parse(url))
        return image_data
    rescue StandardError => e
        puts "Error downloading image: #{e.message}"
        return nil
    end
end


def create_random_post(animal_types)
    # generate bsky session
    session = bsky_connect
    
    # get image url
    image_url = get_animal(animal_types.sample)
    
    # download and store image data
    img_bytes = get_image(image_url)

    # upload and store image to bsky server
    uploaded_image = upload_image(session, img_bytes, image_url)
    
    # check if image uploaded correctly
    if(uploaded_image)
        image_post = build_image_post(session, uploaded_image)
        puts send_post(session, image_post).body
    else
        puts "Image upload failed."
    end
end

if(ARGV[0] == "random") # call for random post
    create_random_post(animal_types)
else
    session = bsky_connect
    puts get_notifs(session)
end