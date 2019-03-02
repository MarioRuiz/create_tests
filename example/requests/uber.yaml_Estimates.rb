##################################################
# Uber API
# version: 1.0.0
# description:
#     Move your app forward with the Uber API
##################################################
module Swagger
  module UberApi
    module V1_0_0
      module Estimates

        # operationId: priceEstimates, method: get
        # summary: Price Estimates
        # description:
        #     The Price Estimates endpoint returns an estimated price range for each product offered at a given location. The price estimate is provided as a formatted string with the full price range and the localized currency symbol.<br><br>The response also includes low and high estimates, and the [ISO 4217](http://en.wikipedia.org/wiki/ISO_4217) currency code for situations requiring currency conversion. When surge is active for a particular product, its surge_multiplier will be greater than 1, but the price estimate already factors in this multiplier.
        # parameters description:
        #    start_latitude: (number) (required) Latitude component of start location.
        #    start_longitude: (number) (required) Longitude component of start location.
        #    end_latitude: (number) (required) Latitude component of end location.
        #    end_longitude: (number) (required) Longitude component of end location.
        def self.price_estimates(start_latitude, start_longitude, end_latitude, end_longitude)
          {
            path: "/v1/estimates/price?start_latitude=#{start_latitude}&start_longitude=#{start_longitude}&end_latitude=#{end_latitude}&end_longitude=#{end_longitude}&",
            method: :get,
            responses: {
              '200': {
                message: "An array of price estimates by product",
                data: [
                  {
                    product_id: "string",
                    currency_code: "string",
                    display_name: "string",
                    estimate: "string",
                    low_estimate: 0,
                    high_estimate: 0,
                    surge_multiplier: 0,
                  },
                ],
              },
              'default': {
                message: "Unexpected error",
                data: {
                  code: 0,
                  message: "string",
                  fields: "string",
                },
              },
            },
          }
        end

        # operationId: timeEstimates, method: get
        # summary: Time Estimates
        # description:
        #     The Time Estimates endpoint returns ETAs for all products offered at a given location, with the responses expressed as integers in seconds. We recommend that this endpoint be called every minute to provide the most accurate, up-to-date ETAs.
        # parameters description:
        #    start_latitude: (number) (required) Latitude component of start location.
        #    start_longitude: (number) (required) Longitude component of start location.
        #    customer_uuid: (string)  Unique customer identifier to be used for experience customization.
        #    product_id: (string)  Unique identifier representing a specific product for a given latitude & longitude.
        def self.time_estimates(start_latitude, start_longitude, customer_uuid: "", product_id: "")
          {
            path: "/v1/estimates/time?start_latitude=#{start_latitude}&start_longitude=#{start_longitude}&customer_uuid=#{customer_uuid}&product_id=#{product_id}&",
            method: :get,
            responses: {
              '200': {
                message: "An array of products",
                data: [
                  {
                    product_id: "string",
                    description: "string",
                    display_name: "string",
                    capacity: 0,
                    image: "string",
                  },
                ],
              },
              'default': {
                message: "Unexpected error",
                data: {
                  code: 0,
                  message: "string",
                  fields: "string",
                },
              },
            },
          }
        end
      end
    end
  end
end
