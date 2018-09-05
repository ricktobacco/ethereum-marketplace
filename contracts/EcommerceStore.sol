pragma solidity ^0.4.24;

import "contracts/Escrow.sol";
import "contracts/ClaimHolder.sol";

contract EcommerceStore 
{    
    address public arbiter;
    mapping (address => uint) claims;
    mapping (address => mapping(uint => Product)) stores;
    mapping (uint => address) productIdInStore;
    mapping (uint => address) productEscrow;
    
    //event ClaimValid(ClaimHolder _identity, uint256 claimType);
    //event ClaimInvalid(ClaimHolder _identity, uint256 claimType);
    event ReleaseFunds(uint _productId, address _buyer);
    event NewProduct (
        uint _productId, 
        string _name, 
        string _category, 
        string _imageLink, 
        string _descLink, 
        uint _startTime, 
        uint _price, 
        uint _productCondition
    );
    enum ProductCondition {New, Used}
    struct Product {
        uint id;
        string name;
        string category;
        string imageLink;
        string descLink;
        uint startTime;
        uint price;
        ProductCondition condition;
        address buyer;
    }
    uint public productIndex;
    
    constructor(address _arbiter) public {
        productIndex = 0;
        arbiter = _arbiter;
    }

    function bless() public {
        if (claims[msg.sender] != 1) {
            claims[msg.sender] = 1;
        }
    }

    function addProductToStore(
        string _name, string _category, 
        string _imageLink, string _descLink, 
        uint _startTime, uint _price, 
        uint _productCondition) public {
        productIndex = productIndex + 1;
        Product memory product = Product(
            productIndex, 
            _name, _category, 
            _imageLink, _descLink, 
            _startTime, _price, 
            ProductCondition(_productCondition), 0);
        stores[msg.sender][productIndex] = product;
        productIdInStore[productIndex] = msg.sender;
        emit NewProduct(
            productIndex, _name, 
            _category, _imageLink,
            _descLink, _startTime, 
            _price, _productCondition);
    }
    
    function getProduct(uint _productId) 
    public view returns (uint, string, string, string, string, uint, uint, ProductCondition, address) 
    {     
        Product memory product = stores[productIdInStore[_productId]][_productId];
        return (product.id, product.name, product.category, product.imageLink,
            product.descLink, product.startTime, product.price,
            product.condition, product.buyer);
    }
    
    function buy(uint _productId) payable public {
        Product memory product = stores[productIdInStore[_productId]][_productId];
        require(product.buyer == address(0));
        require(msg.sender != productIdInStore[_productId]);
        require(msg.value >= product.price);
        //request claim from arbiter
        //ClaimHolder(claims[msg.sender]) beneficiaryIdentity = ClaimHolder(_beneficiary);
        //require(verifier.checkClaim(beneficiaryIdentity, 7));
        product.buyer = msg.sender;
        stores[productIdInStore[_productId]][_productId] = product;
        Escrow escrow = (new Escrow).value(msg.value)(_productId, msg.sender, productIdInStore[_productId], arbiter);
        productEscrow[_productId] = escrow;
    }

    function escrowInfo(uint _productId) view public returns (address, address, address, bool, uint, uint) {
        return Escrow(productEscrow[_productId]).escrowInfo();
    }

    function releaseAmountToSeller(uint _productId) public {
        if (claims[msg.sender] == 1 || msg.sender == arbiter) {
            Escrow(productEscrow[_productId]).releaseAmountToSeller(msg.sender);
            if (Escrow(productEscrow[_productId]).fundsDisbursed() == true) {
                Product memory product = stores[productIdInStore[_productId]][_productId];
                emit ReleaseFunds(_productId, product.buyer);
            }
        }
    }
    
    function refundAmountToBuyer(uint _productId) public {
        if (claims[msg.sender] == 1 || msg.sender == arbiter) {
            Escrow(productEscrow[_productId]).refundAmountToBuyer(msg.sender);
            if (Escrow(productEscrow[_productId]).fundsDisbursed() == true) {
                Product memory product = stores[productIdInStore[_productId]][_productId];
                product.buyer = address(0);
                emit ReleaseFunds(_productId, product.buyer);
            }
        }
    }

    /**
      * @dev Recover signer address from a message by using their signature
      * @param sig bytes signature, the signature is generated using web3.eth.sign()
      * @param dataHash bytes32 message, the hash is the signed message. What is recovered is the signer address.
    */
    // function getRecoveredAddress(bytes sig, bytes32 dataHash)
    // internal pure returns (address addr) {
    //     bytes32 r;
    //     bytes32 s;
    //     uint8 v;

    //     if (sig.length != 65) {
    //         return (address(0));
    //     }
    //     // Divide the signature in r, s and v variables for ecrecover
    //     // the only way to get them currently is to use assembly.
    //     // solium-disable-next-line security/no-inline-assembly
    //     assembly {
    //       r := mload(add(sig, 32))
    //       s := mload(add(sig, 64))
    //       v := byte(0, mload(add(sig, 96)))
    //     }
    //     if (v < 27) {
    //         v += 27;
    //     }
    //     // If the version is correct return the signer address
    //     if (v != 27 && v != 28) {
    //         return (address(0));
    //     } else {
    //         // solium-disable-next-line arg-overflow
    //         return ecrecover(dataHash, v, r, s);
    //     }
    // }
    // function checkClaim(ClaimHolder _identity, uint256 claimType)
    // public returns (bool claimValid) {
    //     if (claimIsValid(_identity, claimType)) {
    //         emit ClaimValid(_identity, claimType);
    //         return true;
    //     } else {
    //         emit ClaimInvalid(_identity, claimType);
    //         return false;
    //     }
    // }
    // function claimIsValid(ClaimHolder _identity, uint256 claimType)
    // public view returns (bool claimValid) {
    //     uint256 foundClaimType;
    //     uint256 scheme;
    //     address issuer;
    //     bytes memory sig;
    //     bytes memory data;
    //     bytes32 claimId = keccak256(trustedClaimHolder, claimType);
    //     // Fetch claim from user
    //     ( foundClaimType, scheme, issuer, sig, data, ) = _identity.getClaim(claimId);

    //     bytes32 dataHash = keccak256(_identity, claimType, data);
    //     bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));
    //     // Recover address of data signer
    //     address recovered = getRecoveredAddress(sig, prefixedHash);
    //     // Take hash of recovered address
    //     bytes32 hashedAddr = keccak256(recovered);
    //     // Does the trusted identifier have they key which signed the user's claim?
    //     return trustedClaimHolder.keyHasPurpose(hashedAddr, 1);
    // }
}
