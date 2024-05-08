require_relative 'bsky'
require_relative 'animals'
require 'net/http'
require 'uri'
require 'json'
require 'date'
require 'open-uri'
require 'stringio'


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
        image_post = build_image_post(uploaded_image)
        puts send_post(session, image_post)
    else
        puts "Image upload failed."
    end
end

def do_replies(session)
    # get notifications and split into categories
    notifications = get_notifs(session)
    #puts notifications
    # only clone replies array if not nil
    notif_replies = notifications["replies".to_sym]
    notif_mentions = notifications["mentions".to_sym]

    animal_types = get_animal_types
    
    # store handle so that it can be removed from replies if needed
    handle = "@#{get_bsky_handle}"


    for reply in notif_replies
        # info of reply
        reply_uri = reply['uri']
        reply_cid = reply['cid']

        # reply data
        reply_text = reply['record']['text'].downcase.strip
        
        # data of thread root
        root_uri = reply['record']['reply']['root']['uri']
        root_cid = reply['record']['reply']['root']['cid']

        if animal_types.include?(reply_text) # reply is in the format we want, we can send an image of the requested animal
            # get image url
            image_url = get_animal(reply_text)
            # download and store image data
            img_bytes = get_image(image_url)
            # upload and store image to bsky server
            uploaded_image = upload_image(session, img_bytes, image_url)
            # create text
            text = "Here's your #{reply_text}!"
        else
            # reply is not in the format we want, send any animal
            # get image of random animal
            animal = animal_types.sample
            image_url = get_animal(animal)
            # download image
            img_bytes = get_image(image_url)
            # upload image
            uploaded_image = upload_image(session, img_bytes, image_url)
            text = "ok cool. here's a #{animal}"
        end
        # check if image uploaded correctly
        if(uploaded_image)
            image_post = build_image_reply(session, uploaded_image, reply_uri, reply_cid, root_uri, root_cid, text)
            puts send_post(session, image_post).body
        else
            puts "Image upload failed."
        end
    end

    for mention in notif_mentions
        # info of mention
        mention_uri = mention["uri"]
        mention_cid = mention["cid"]

        # mention data
        mention_text = mention['record']['text'].downcase.strip
        if mention_text.start_with?(handle) # remove account handle from mention
            mention_text.sub! handle, ''
        end
        mention_text = mention_text.strip
        #puts mention_text
        
        # check if reply is a part of a chain, and grab root the uri and cid if it is
        if mention["record"].include?("reply")
            root_uri = mention['record']['reply']['root']['uri']
            root_cid = mention['record']['reply']['root']['cid']
        else # set the root to the same as the parent post
            root_uri = mention["uri"]
            root_cid = mention["cid"]
        end

        # time to post

        if animal_types.include?(mention_text) # reply is in the format we want, we can send an image of the requested animal
            # get image url
            image_url = get_animal(mention_text)
            # download and store image data
            img_bytes = get_image(image_url)
            # upload and store image to bsky server
            uploaded_image = upload_image(session, img_bytes, image_url)
            # create text
            text = "Here's your #{mention_text}!"
        else
            # reply is not in the format we want, send any animal
            # get image of random animal
            animal = animal_types.sample
            image_url = get_animal(animal)
            # download image
            img_bytes = get_image(image_url)
            # upload image
            uploaded_image = upload_image(session, img_bytes, image_url)
            text = "ok cool. here's a #{animal}"
        end
        # check if image uploaded correctly
        if(uploaded_image)
            image_post = build_image_reply(uploaded_image, mention_uri, mention_cid, root_uri, root_cid, text)
            puts send_post(session, image_post).body
        else
            puts "Image upload failed."
        end
    end
    mark_as_read(session)
end

if(ARGV[0] == "random") # call for random post
    create_random_post(get_animal_types)
elsif (ARGV[0] == "reply")
    session = bsky_connect
    do_replies(session)
else
    puts "Parameters: random, reply"
end