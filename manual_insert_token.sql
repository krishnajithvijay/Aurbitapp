-- Manually insert the token that we saw in your logs
-- This bypasses the app entirely to ensure the database has the data.

INSERT INTO user_fcm_tokens (user_id, token, device_type)
VALUES (
    'f486d96b-2a40-4cbf-9662-e87f67bbc267', -- The User ID from your logs
    'fFBUpf_DTqeqDhCz6DbOm7:APA91bFBnT8dBeiMD4TP5N8TtGQ3akUwJojFBP1y0Qpyvj2tKuI7h-JC0DGEPnw7UqW08tBcxcYPraaxKf2H-K6UpswfqkhvG2rFoMZ-jbi9lJTRO8k2j0s', -- The Token from your logs
    'android'
)
ON CONFLICT (user_id, token) DO UPDATE 
SET last_updated = NOW();
