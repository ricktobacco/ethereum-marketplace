var ecommerce_store_artifacts = require('./build/contracts/EcommerceStore.json')
var contract = require('truffle-contract')
var Web3 = require('web3')
var provider = new Web3.providers.HttpProvider("http://localhost:8545");
var EcommerceStore = contract(ecommerce_store_artifacts);
EcommerceStore.setProvider(provider);

var mongoose = require('mongoose');
mongoose.Promise = global.Promise;
var ProductModel = require('./product');
mongoose.connect("mongodb://localhost:27017/ebay_dapp");
var db = mongoose.connection;
db.on('error', console.error.bind(console, 'MongoDB connection error:'));

var express = require('express');

var app = express();

app.use(function(req, res, next) {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  next();
});

app.listen(3000, function() {
  console.log("Ebay on Ethereum server listening on port 3000");
});

app.get('/', function(req, res) {
  res.send("Hello, Ethereum!");
});

app.get('/products', function(req, res) {
  var query = {};
  if (req.query.category !== undefined) {
    query['category'] = {$eq: req.query.category};
  }

  ProductModel.find(query, null, {sort: 'startTime'}, function(err, items) {
    console.log(items.length);
    res.send(items);
  });
});

app.get('/fb', function(req, res) {
  console.log("yeah freddy");
  let web3 = new Web3(provider);
  EcommerceStore.deployed().then(function(f) {
    f.bless({from: web3.eth.accounts[0], gas:4400000}).then(function(f) {
    });
  });
});

setupProductEventListner();
setupReleaseFundsEventListner();

function setupProductEventListner() {
  var productEvent;
  EcommerceStore.deployed().then(function(i) {
    productEvent = i.NewProduct({fromBlock: 0, toBlock: 'latest'})
    productEvent.watch(function(err, result) {
      if (err) {
        console.log(err)
        return;
      }
      console.log(result.args);
      saveProduct(result.args);
    });
  });
}

function setupReleaseFundsEventListner() {
  var productEvent;
  EcommerceStore.deployed().then(function(i) {
    productEvent = i.ReleaseFunds({fromBlock: 0, toBlock: 'latest'})
    productEvent.watch(function(err, result) {
      if (err) {
        console.log(err)
        return;
      }
      console.log(result.args);
      updateProduct(result.args);
    });
  });
}

function saveProduct(product) {
  ProductModel.findOne({ 'blockchainId': product._productId.toNumber() }, function (err, dbProduct) {
    if (dbProduct != null) {
      return;
    }
    var p = new ProductModel({name: product._name, blockchainId: product._productId,
      category: product._category, ipfsImageHash: product._imageLink, ipfsDescHash: product._descLink,
     startTime: product._startTime, price: product._price, condition: product._productCondition
     });

    p.save(function(error) {
      if (error) {
        console.log(error);
      } else {
        ProductModel.count({}, function(err, count) {
         console.log("count is " + count);
        });
      }
    });
  }) 
}
function updateProduct(product) {
  ProductModel.findOne({ 'blockchainId': product._productId.toNumber() }, function (err, dbProduct) {
    if (dbProduct != null) {
      dbProduct.buyer = product._buyer;
      dbProduct.save(function(error) {
        if (error) {
          console.log(error);
        } 
      });
    }
  }) 
}