# This file contains all Bluesky-related functions.
require 'dotenv'
require 'net/http'
require 'uri'
require 'json'
require 'date'
require 'open-uri'
require 'stringio'
require 'httparty'
require_relative('animals')

Dotenv.load('bsky.env')

def bsky_connect
    # creates bsky connection
    request = HTTParty.post(
        'https://bsky.social/xrpc/com.atproto.server.createSession',
        body: JSON.dump({
            "identifier" => ENV['BSKY_IDENTIFIER'],
            "password" => ENV['BSKY_APP_PASSWORD']
        }),
        headers: {
            "Content-Type" => "application/json"
        })
    
    if request.success?
        return JSON.parse(request.body)
    else
        puts "Error: Code #{request.code}\nResponse: #{request}"
        exit
    end
end

def get_bsky_handle
    return ENV["BSKY_IDENTIFIER"]
end

def send_post(session, post)
    # sends a generated post
    request = HTTParty.post(
        'https://bsky.social/xrpc/com.atproto.repo.createRecord',
        body: JSON.dump({
            "repo" => session["did"],
            "collection" => "app.bsky.feed.post",
            "record" => JSON.parse(post)
        }),
        headers: {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer " + session["accessJwt"]
        },
    )
    if request.success?
        return JSON.parse(request.body)
    else
        puts "Error: Code #{request.code}\nResponse: #{request}"
        exit
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

def build_image_post(blob)
    # prepares a self image post
    post = JSON.dump({
            "text" => "",
            "createdAt" => DateTime.now,
            "langs" => ["en-US"],
            "embed" => {
                "$type" => "app.bsky.embed.images",
                "images" => [
                    {
                        "alt" => "",
                        "image" => blob
                    }
                ]
            }
        })
    return post
end

def build_image_reply(blob, uri, cid, root_uri, root_cid, text = nil)
    # prepares a reply with an image

    post = JSON.dump({
        "$type" => "app.bsky.feed.post",
        "text" => "#{text}",
        "createdAt" => DateTime.now,
        "langs" => ["en-US"],
        "embed" => {
            "$type" => "app.bsky.embed.images",
            "images" => [
                {
                    "alt" => "",
                    "image" => blob
                }
            ]
        },
        "reply" => {
            "root" => {
                "uri" => root_uri,
                "cid" => root_cid
            },
            "parent" => {
                "uri" => uri,
                "cid" => cid
            }
        }
    })
    return post
end

def upload_image(session, img_bytes, image_url)
    # uploads the image to bsky and gets the blob
    if(img_bytes.length > 1000000)
        puts "Error: image is too large"
        return nil 
    end

    # upload image
    resp = HTTParty.post(
        'https://bsky.social/xrpc/com.atproto.repo.uploadBlob',
        headers: {
            "Content-Type" => "application/#{File.extname(image_url)}",
            "Authorization" => "Bearer #{session["accessJwt"]}"            
        },
        body: img_bytes)
    if resp.success?
        blob_response = JSON.parse(resp.body)
        blob = blob_response["blob"]
        return blob
    else
        puts "Error: Code #{request.code}\nResponse: #{resp}"
        exit
    end
end


def get_notifs(session)
    # fetch a list of reply and mention notifications
    replies = []
    mentions = []
    resp = HTTParty.get(
        'https://bsky.social/xrpc/app.bsky.notification.listNotifications',
        headers: {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{session["accessJwt"]}"
        })

    if resp.success?
        # get json of response
        notif_json = JSON.parse(resp.body)

        # retrieve 5 most recent notifications
        notifs = notif_json['notifications'][0..5]

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

        # return separated arrays
        return {"replies": replies, "mentions": mentions}
    else
        puts "Error: Code #{request.code}\nResponse: #{resp}"
        exit
    end
end

def mark_as_read(session)
    # mark all notifications as read
    resp = HTTParty.post(
        'https://bsky.social/xrpc/app.bsky.notification.updateSeen',
        headers: {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{session["accessJwt"]}"
        },
        body: JSON.dump({
            "seenAt" => DateTime.now
        })
    )
    if resp.success?
        return resp
    else
        puts "Error: Code #{request.code}\nResponse: #{resp}"
        exit
    end
end

