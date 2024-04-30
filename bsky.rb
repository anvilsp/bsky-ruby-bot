# This file contains all Bluesky-related functions.
require 'dotenv'
require 'net/http'
require 'uri'
require 'json'
require 'date'
require 'open-uri'
require 'stringio'

Dotenv.load('bsky.env')

def bsky_connect
    # creates bsky connection
    uri = URI.parse("https://bsky.social/xrpc/com.atproto.server.createSession")
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request.body = JSON.dump({
        "identifier" => ENV['BSKY_IDENTIFIER'],
        "password" => ENV['BSKY_APP_PASSWORD']
    })

    req_options = {
        use_ssl: uri.scheme == "https",
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
    end
    
    # check if the connection was successful, otherwise give an error
    case response
    when Net::HTTPSuccess
        return JSON.parse(response.body)
    else
        puts "Session error: #{response.code} #{response.message}"
        return nil
    end
end

def build_post(text)
    # prepares a self text post
    now = DateTime.now
    post = JSON.dump({
        "text" => text,
        "createdAt" => now,
        "langs" => ["en-US"]
    })
    return post
end

def create_text_post(session)
    # creates a test post
    post = build_post("Hello world!")
    uri = URI.parse("https://bsky.social/xrpc/com.atproto.repo.createRecord")
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request["Authorization"] = "Bearer #{session["accessJwt"]}"
    request.body = JSON.dump({
        "repo" => session["did"],
        "collection" => "app.bsky.feed.post",
        "record" => JSON.parse(post)
    })
    req_options = {
        use_ssl: uri.scheme == "https"
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
    end

end

def upload_image(session, img_bytes, image_url)
    # uploads the image to bsky and gets the blob
    if(img_bytes.length > 1000000)
        puts "Error: image is too large"
        return nil 
    end

    # upload image
    uri = URI.parse("https://bsky.social/xrpc/com.atproto.repo.uploadBlob")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "image/#{File.extname(image_url)}"
    request["Authorization"] = "Bearer #{session["accessJwt"]}"
    request.body = img_bytes

    req_options = {
        use_ssl: uri.scheme == "https"
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
    end

    # return the blob if the image is successfully uploaded - else nil
    case response
    when Net::HTTPSuccess
        blob_response = JSON.parse(response.body)
        blob = blob_response["blob"]
        return blob
    else
        puts "Failed to upload image: #{response.code} #{response.message}"
        return nil
    end
end

def send_image_post(session, blob)
    # initialize request
    uri = URI.parse("https://bsky.social/xrpc/com.atproto.repo.createRecord")
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request["Authorization"] = "Bearer #{session["accessJwt"]}"
    # post body
    request.body = JSON.dump({
        "repo" => session["did"],
        "collection" => "app.bsky.feed.post",
        "record" => {
            "text" => "",
            "createdAt" => DateTime.now,
            "embed" => {
                "$type" => "app.bsky.embed.images",
                "images" => [
                    {
                        "alt" => "",
                        "image" => blob
                    }
                ]
            }
        }
    })

    req_options = {
        use_ssl: uri.scheme == "https"
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
    end
    return response
end

def get_notifs(session)
    # fetch a list of reply and mention notifications
    replies = []
    mentions = []

    uri = URI.parse("https://bsky.social/xrpc/app.bsky.notification.listNotifications")
    uri.query = URI.encode_www_form(accessJwt: session["accessJwt"])

    # new http object
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    # create get request
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{session["accessJwt"]}"

    # process request
    response = http.request(request)

    # get json of response
    notif_json = JSON.parse(response.body)

    # retrieve 50 most recent notifications
    notifs = notif_json['notifications'][0..50]

    # iterate through notifications
    for item in notifs
        # only process unread notifications that are replies or mentions
        if (item['reason'] != "reply" and item['reason'] != "mention") or item['isRead']
            next
        elsif item['reason'] == "reply" # append replies to an array
            replies.push(item)
        elsif item['reason'] == "mention" # append mentions to an array
            mentions.push(item)
        end
    end
    mark_as_read(session)
    return {"replies": replies, "mentions": mentions}
end

def mark_as_read(session)
    # mark all notifications as read
    # initialize request
    uri = URI.parse("https://bsky.social/xrpc/app.bsky.notification.updateSeen")
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request["Authorization"] = "Bearer #{session["accessJwt"]}"
    request.body = JSON.dump({
        "seenAt" => DateTime.now
    })

    req_options = {
        use_ssl: uri.scheme == "https"
    }

    # send request
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
    end
    return response
end
