/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_108570809")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.role = \"seller\" || @request.auth.role = \"admin\" || (@request.auth.role = \"customer\" && @request.auth.customer = \"\")"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_108570809")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.role = \"seller\" || @request.auth.role = \"admin\""
  }, collection)

  return app.save(collection)
})
