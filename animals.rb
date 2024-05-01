require 'net/http'
require 'uri'
require 'json'
require 'date'
require 'open-uri'
require 'stringio'

def get_animal_types
    return ["dog", "cat", "bunny", "duck", "lizard"]
end

def get_animal(animal)
    animal_types = get_animal_types
    case animal
    when animal_types[0]
        response = Net::HTTP.get(URI.parse("https://dog.ceo/api/breeds/image/random"))
        return JSON.parse(response)["message"]
    when animal_types[1]
        return "https://cataas.com/cat"
    when animal_types[2]
        response = Net::HTTP.get(URI.parse("https://api.bunnies.io/v2/loop/random/?media=gif,png"))
        return JSON.parse(response)["media"]["poster"]
    when animal_types[3]
        response = Net::HTTP.get(URI.parse("https://random-d.uk/api/v2/random?type=jpg"))
        return JSON.parse(response)["url"]
    when animal_types[4]
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