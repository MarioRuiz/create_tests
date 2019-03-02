##################################################
# Uber API
# version: 1.0.0
# description:
#     Move your app forward with the Uber API
##################################################
module Swagger
  module UberApi
    module V1_0_0
      module User

        # operationId: profileUser, method: get
        # summary: User Profile
        # description:
        #     The User Profile endpoint returns information about the Uber user that has authorized with the application.
        def self.profile_user()
          {
            path: "/v1/me",
            method: :get,
            responses: {
              '200': {
                message: "Profile information for a user",
                data: {
                  first_name: "string",
                  last_name: "string",
                  email: "string",
                  picture: "string",
                  promo_code: "string",
                },
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

        # operationId: activityUser, method: get
        # summary: User Activity
        # description:
        #     The User Activity endpoint returns data about a user's lifetime activity with Uber. The response will include pickup locations and times, dropoff locations and times, the distance of past requests, and information about which products were requested.<br><br>The history array in the response will have a maximum length based on the limit parameter. The response value count may exceed limit, therefore subsequent API requests may be necessary.
        # parameters description:
        #    offset: (integer)  Offset the list of returned results by this amount. Default is zero.
        #    limit: (integer)  Number of items to retrieve. Default is 5, maximum is 100.
        def self.activity_user(offset: "", limit: "")
          {
            path: "/v1/history?offset=#{offset}&limit=#{limit}&",
            method: :get,
            responses: {
              '200': {
                message: "History information for the given user",
                data: {
                  offset: 0,
                  limit: 0,
                  count: 0,
                  history: [
                    {
                      uuid: "string",
                    },
                  ],
                },
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
