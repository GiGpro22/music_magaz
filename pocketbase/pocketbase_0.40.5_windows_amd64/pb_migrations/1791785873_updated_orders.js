/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3527180448")

  // update collection data
  unmarshal({
    "listRule": "@request.auth.id != \"\"",
    "viewRule": "@request.auth.id != \"\""
  }, collection)

  // update field
  collection.fields.addAt(2, new Field({
    "help": "",
    "hidden": false,
    "id": "select2063623452",
    "maxSelect": 1,
    "name": "status",
    "presentable": false,
    "required": true,
    "system": false,
    "type": "select",
    "values": [
      "created",
      "new",
      "paid",
      "shipped",
      "cancelled",
      "completed"
    ]
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3527180448")

  // update collection data
  unmarshal({
    "listRule": "@request.auth.role = \"seller\" || @request.auth.role = \"admin\" || (@request.auth.role = \"customer\" && customer = @request.auth.customer)",
    "viewRule": "@request.auth.role = \"seller\" || @request.auth.role = \"admin\" || (@request.auth.role = \"customer\" && customer = @request.auth.customer)"
  }, collection)

  // update field
  collection.fields.addAt(2, new Field({
    "help": "",
    "hidden": false,
    "id": "select2063623452",
    "maxSelect": 1,
    "name": "status",
    "presentable": false,
    "required": true,
    "system": false,
    "type": "select",
    "values": [
      "new",
      "paid",
      "shipped",
      "cancelled",
      "completed"
    ]
  }))

  return app.save(collection)
})
