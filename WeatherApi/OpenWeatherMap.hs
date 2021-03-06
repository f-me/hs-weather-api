{-# LANGUAGE OverloadedStrings #-}
module WeatherApi.OpenWeatherMap (initApi) where

import Network.HTTP
import Network.URI
import WeatherApi hiding (humidity)
import Codec.Binary.UTF8.String (encodeString)
import Data.ByteString.Char8 (pack, unpack)
import Data.Aeson
import Data.Aeson.TH
import Data.Attoparsec.ByteString hiding (Result(..))
import Data.Maybe

import Control.Applicative
import qualified Data.Vector as V

import WeatherApi.Util

apiUrl = "http://api.openweathermap.org/data/2.5/weather?"

type ApiKey = String

instance FromJSON Weather where
  parseJSON (Object o) = do
    Object m <- o .: "main"
    Weather
      <$> pure 0.0
      <*> (m .: "temp")
      <*> pure ""
      <*> pure ""
      <*> pure ""

-- | Make config for use with WeatherApi functions
initApi :: ApiKey -> Config
initApi key =
    let params = [("units", "metric"), ("appid", key)]
        urn c  = urlEncodeVars $ params ++ [("q", encodeString c)]
    in Config { apiHost  = "api.openweathermap.org"
              , apiPort  = 80
              , queryFun = makeQueryFun urn
              }

retrieve s urn =
    case parseURI $ apiUrl ++ urn of
      Nothing  -> return $ Left $ NetworkError "Invalid URL"
      Just uri -> get s uri

get s uri = do
  eresp <- sendHTTP s (Request uri GET [] "")
  case eresp of
    Left err  -> return $ Left $ NetworkError $ show err
    Right res -> return $ Right $ rspBody res

-- | This return function witch will actualy retrieve and parse weather from stream
makeQueryFun :: (String -> String)
                -> (HandleStream String)
                -> String
                -> IO ApiResponse
makeQueryFun q stream city =
    do
      resp <- retrieve stream $ q city
      case resp of
        Left err -> return $ Left err
        Right c  -> do
          case maybeResult $ parse json $ pack c of
            Nothing -> return $ Left $ ParseError "Bad response"
            Just v  ->
              return $ case fromJSON v :: Result Weather of
                Error e   -> Left $ ParseError $ "Can't parse data: " ++ e
                Success v -> Right v

