require('dotenv').config();

async function bskyConnect() {
    request = await fetch("https://bsky.social/xrpc/com.atproto.server.createSession",
        {
            method: "POST",
            body: JSON.stringify({
                "identifier": process.env.BSKY_IDENTIFIER,
                "password": process.env.BSKY_APP_PASSWORD
            }),
            headers: {
                "Content-Type": "application/json"
            }
        }
    );
    return await request;
}

async function getBskyHandle() {
    return process.env.BSKY_IDENTIFIER;
}

async function sendPost(session, post) {
    request = await fetch("https://bsky.social/xrpc/com.atproto.repo.createRecord",
        {
            method: "POST",
            body: JSON.stringify({
                "repo": session["did"],
                "collection": "app.bsky.feed.post",
                "record": post
            }),
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${session['accessJwt']}`
            }
        }
    )
    const result = await request.json();
    return await result;
}

function buildPost(text) {
    post = {
        "text": text,
        "createdAt": new Date().toISOString(),
        "langs": ["en-US"]
    }
    return post;
}

function buildImagePost(blob) {
    post = {
        "text": "",
        "createdAt": new Date().toIsoString(),
        "langs": ["en-US"],
        "embed": {
            "$type": "app.bsky.embed.images",
            "images": [
                {
                    "alt": "",
                    "image": blob
                }
            ]
        }
    }
    return post;
}

function buildImageReply(blob, uri, cid, root_uri, root_cid, text) {
    post = {
        "$type": "app.bsky.feed.post",
        "text": `${text}`,
        "createdAt": new Date().toIsoString(),
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
    return post;
}

async function uploadImage(session, img_bytes, image_url) {

    file_ext = image_url.split('.').pop();

    if(img_bytes.length > 1000000) {
        console.log("Error: image is too large");
        return;
    }

    resp = await fetch("https://bsky.social/xrpc/com.atproto.repo.createRecord",
    {
        method: "POST",
        body: img_bytes,
        headers: {
            "Content-Type": `application/${file_ext}`,
            "Authorization": `Bearer ${session['accessJwt']}`
        }
    });

    return await resp;
}

async function getNotifs(session) {
    // fetch a list of reply and mention notifications
    let replies = [];
    let mentions = [];
    let resp = await fetch("https://bsky.social/xrpc/app.bsky.notification.listNotifications", {
        headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${session['accessJwt']}`
        }
    });

    // get json of response
    let notif_json = await resp.json();

    // retrieve 5 most recent notifications
    let notifs = await notif_json['notifications'].slice(0, 5)

    // iterate through notifications
    for(const item of notifs) {
        // only process unread notifications that are replies or mentions
        if((item['reason'] != "reply" && item['reason'] != "mention") || item['isRead'])
            continue;
        else if(item['reason'] == "reply")
            replies.push(item)
        else if(item['reason'] == "mention")
            mentions.push(item)
    }

    // return separated arrays
    return {"replies": replies, "mentions": mentions}
}

async function markAsRead(session) {
    let resp = await fetch("https://bsky.social/xrpc/app.bsky.notification.listNotifications", {
        headers: {
            "Content-Type": "application/json",
            "Authorizaton": `Bearer ${session['accessJwt']}`
        },
        body: JSON.stringify({
            "seenAt": new Date().toIsoString()
        })
    });
    return resp;
}

async function main() {
    const result = await bskyConnect();
    const session = await result.json();
    let newPost = await getNotifs(session);
    console.log(newPost);
}

main();