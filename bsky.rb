# This file contains all Bluesky-related functions.
require 'dotenv'
require 'net/http'
require 'uri'
require 'json'
require 'date'
require 'open-uri'
require 'stringio'
require 'httparty'

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
    return JSON.parse(request.body)
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

def build_image_post(session, blob)
    # prepares a self image post
    post = JSON.dump({
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
        })
    return post
end

def build_image_reply(session, uri, cid, root_uri = nil, root_cid = nil, blob)
    # prepares a reply with an image

    # set cids if the root message is the same as the reply 
    if root_uri == nil
        root_uri = uri
    end
    if root_cid == nil
        root_cid = cid
    end

    post = JSON.dump({
        "$type" => "app.bsky.feed.post",
        "text" => "",
        "createdAt" => DateTime.now,
        "langs" => ["en_US"],
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

    # upload image (httparty)
    resp = HTTParty.post(
        'https://bsky.social/xrpc/com.atproto.repo.uploadBlob',
        headers: {
            "Content-Type" => "application/#{File.extname(image_url)}",
            "Authorization" => "Bearer #{session["accessJwt"]}"            
        },
        body: img_bytes)
    blob_response = JSON.parse(resp.body)
    blob = blob_response["blob"]
    return blob
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

    # get json of response
    notif_json = JSON.parse(resp.body)

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
    return resp
end
