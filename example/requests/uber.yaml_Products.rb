##################################################
# Uber API
# version: 1.0.0
# description:
#     Move your app forward with the Uber API
##################################################
module Swagger
  module UberApi
    module V1_0_0
      module Products

        # operationId: listProducts, method: get
        # summary: Product Types
        # description:
        #     The Products endpoint returns information about the Uber products offered at a given location. The response includes the display name and other details about each product, and lists the products in the proper display order.
        # parameters description:
        #    latitude: (number) (required) Latitude component of location.
        #    longitude: (number) (required) Longitude component of location.
        def self.list_products(latitude, longitude)
          {
            path: "/v1/products?latitude=#{latitude}&longitude=#{longitude}&",
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
