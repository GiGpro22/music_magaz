/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_4092854851")

  // update collection data
  unmarshal({
    "updateRule": "@request.auth.role = \"seller\" || @request.auth.role = \"admin\" || @request.auth.role = \"customer\""
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_4092854851")

  // update collection data
  unmarshal({
    "updateRule": "@request.auth.role = \"seller\" || @request.auth.role = \"admin\""
  }, collection)

  return app.save(collection)
})
