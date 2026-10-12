/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3527180448")

  // update collection data
  unmarshal({
    "listRule": "@request.auth.role = \"seller\" || @request.auth.role = \"admin\" || (@request.auth.role = \"customer\" && customer = @request.auth.customer)",
    "viewRule": "@request.auth.role = \"seller\" || @request.auth.role = \"admin\" || (@request.auth.role = \"customer\" && customer = @request.auth.customer)"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3527180448")

  // update collection data
  unmarshal({
    "listRule": "@request.auth.id != \"\"",
    "viewRule": "@request.auth.id != \"\""
  }, collection)

  return app.save(collection)
})
