import requests, os, pathlib, json
from datetime import datetime, timezone
from dotenv import load_dotenv

load_dotenv('../bsky.env')

now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def bsky_connect():
    resp = requests.post(
        "https://bsky.social/xrpc/com.atproto.server.createSession",
        json = {
            "identifier": os.getenv("BSKY_IDENTIFIER"),
            "password": os.getenv("BSKY_APP_PASSWORD")
        })
    resp.raise_for_status()
    session = resp.json()
    return session

def get_bsky_handle():
    return os.getenv("BSKY_IDENTIFIER")

def send_post(session, post):
    # sends a generated post
    resp = requests.post(
        "https://bsky.social/xrpc/com.atproto.repo.createRecord",
        json = {
            "repo": session["did"],
            "collection": "app.bsky.feed.post",
            "record": post
        },
        headers = {
            "Authorization": f"Bearer {session['accessJwt']}"
        }
    )
    resp.raise_for_status()
    return resp

def build_post(text):
    # prepares a text post
    post = {
        "text": text,
        "createdAt": now,
        "langs": ["en-US"]
    }
    return post

def build_image_post(blob):
    # prepares a self image post
    post = {
        "text": "",
        "createdAt": now,
        "langs": ["en-US"],
        "embed": {
            "$type": "app.bsky.embed.images",
            "images": {
                "alt": "",
                "image": blob
            }
        }
    }
    return post

def build_image_reply(blob, uri, cid, root_uri, root_cid, text):
    # prepares a reply with an image
    post = {
        "$type": "app.bsky.feed.post",
        "text": f"{text}",
        "createdAt": now,
        "langs": ["en-US"],
        "embed": {
            "$type": "app.bsky.embed.images",
            "images": [
                {
                    "alt": "",
                    "image": blob
                }
            ]
        },
        "reply": {
            "root": {
                "uri": root_uri,
                "cid": root_cid
            },
            "parent": {
                "uri": uri,
                "cid": cid
            }
        }
    }
    return post

def upload_image(session, img_bytes, image_url):
    # uploads the image to bsky and gets the blob
    if(img_bytes.length > 1000000):
        print("Error: image is too large")
        return
    
    # upload image
    resp = requests.post(
        "https://bsky.social/xrpc/com.atproto.repo.uploadBlob",
        headers = {
            "Content-Type": f"application/{pathlib.path(image_url).suffix}",
            "Authorization": f"Bearer {session['accessJwt']}"
        },
        data = img_bytes
    )
    blob_response = resp.json()
    blob = blob_response["blob"]
    return blob

def get_notifs(session):
    # fetch a list of reply and mention notifications
    replies = []
    mentions = []

    # request notifications
    resp = requests.get("https://bsky.social/xrpc/app.bsky.notification.listNotifications",
                     headers = {
                            "Authorization": f"Bearer {session['accessJwt']}"
                        })
    resp.raise_for_status()

    # get json of response
    notif_json = resp.json()

    # retrieve 5 most recent notifications
    notifs = notif_json['notifications'][:5]

    # iterate through notifications
    for item in notifs:
    # get notifications that fit our criteria
        if (item['reason'] != "reply" and item['reason'] != "mention") or item['isRead']:
            continue
        elif item['reason'] == "reply":
            replies.append(item)
        elif item['reason'] == "mention":
            mentions.append(item)

    # return separated arrays
    return {"replies": replies, "mentions": mentions}

def mark_as_read(session):
    # mark notifications as read
    resp = requests.get(
        "https://bsky.social/xrpc/app.bsky.notification.updateSeen",
        headers = {
            "Authorization": f"Bearer {session['accessJwt']}"
        },
        json = {
            "seenAt": now
        }
    )
    resp.raise_for_status()
    return resp