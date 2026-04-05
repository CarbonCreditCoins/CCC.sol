// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    CarbonCreditCoinSupreme.sol

    Arquivo único para GitHub + Remix
    - ERC20 principal CCC
    - Governança centralizada em uma master única
    - Registro declarativo institucional
    - Catálogo de tokens/contratos externos
    - Registro de documentos/hashes
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CarbonCreditCoinSupreme is ERC20, ERC20Burnable, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // =========================================================
    // ROLES
    // =========================================================
    bytes32 public constant PAUSER_ROLE   = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE   = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    // =========================================================
    // TOKEN CORE
    // =========================================================
    string private constant TOKEN_NAME = "Carbon Credit Coin";
    string private constant TOKEN_SYMBOL = "CCC";
    uint8 private constant TOKEN_DECIMALS = 18;

    uint256 public constant MAX_SUPPLY = 20_000_000_000 * 10**18;
    uint256 public constant USD_REFERENCE_PER_CCC_6 = 1_000_000; // US$1.00 com 6 casas
    uint256 public constant KG_CO2_PER_CCC = 164;
    uint256 public constant KG_PER_TON = 1000;

    address public constant INITIAL_MASTER = 0xa14859FdF36c6E077ad7ABa88887317D28544fc4;

    address public masterAccount;
    address public treasury;
    address public operator;
    bool public mintingLocked;
    bool public bootstrapExecuted;

    // =========================================================
    // METADATA
    // =========================================================
    struct ProjectMetadata {
        string projectName;
        string symbolText;
        string logoURI;
        string imageURI;
        string websiteURI;
        string repositoryURI;
        string whitepaperURI;
        string description;
        string jurisdiction;
        string legalNotice;
        string pricingReferenceText;
        string carbonEquivalenceText;
        uint256 referencePriceUSD_6;
        uint256 carbonKgPerCCC;
        bool referencePriceActive;
        bool carbonEquivalenceActive;
        uint256 updatedAt;
    }

    ProjectMetadata public projectMetadata;

    // =========================================================
    // INSTITUTIONAL BACKING (DECLARATIVE)
    // =========================================================
    struct InstitutionalBacking {
        string backingType;
        string declaredCustodian;
        string declaredAuditor;
        string declaredValidator;
        string declaredVerificationText;
        string declaredCertificationText;
        string declaredJurisdiction;
        string issueDateText;
        string maturityText;
        uint256 declaredBackingUSD_6;
        uint256 declaredCarbonKg;
        uint256 declaredCarbonTons_3;
        bool declaredCustodyActive;
        bool declaredAuditActive;
        bool declaredValidationActive;
        bool declaredCertificationActive;
        uint256 updatedAt;
    }

    InstitutionalBacking public institutionalBacking;

    // =========================================================
    // DOCUMENTS / HASHES
    // =========================================================
    enum DocumentType {
        OTHER,
        LOGO,
        IMAGE,
        WHITEPAPER,
        AUDIT_REPORT,
        CUSTODY_LETTER,
        SKR,
        CERTIFICATE,
        VALIDATION_RECORD,
        VERIFICATION_RECORD,
        TERMS,
        COMPLIANCE_FILE,
        LEGAL_OPINION
    }

    struct DocumentRecord {
        uint256 id;
        DocumentType docType;
        string title;
        string issuer;
        string referenceCode;
        string uri;
        string contentHashText;
        bytes32 contentHashBytes32;
        string description;
        bool active;
        uint256 createdAt;
        uint256 updatedAt;
    }

    uint256 private _documentIdCounter;
    mapping(uint256 => DocumentRecord) public documents;
    uint256[] public documentIds;

    // =========================================================
    // EXTERNAL TOKENS
    // =========================================================
    struct ExternalTokenRecord {
        address token;
        string standard;
        string label;
        bool active;
        uint256 createdAt;
        uint256 updatedAt;
    }

    mapping(address => ExternalTokenRecord) public externalTokens;
    address[] public externalTokenList;

    // =========================================================
    // EXTERNAL CONTRACTS
    // =========================================================
    struct ExternalContractRecord {
        address contractAddress;
        string label;
        string contractType;
        bool active;
        uint256 createdAt;
        uint256 updatedAt;
    }

    mapping(address => ExternalContractRecord) public externalContracts;
    address[] public externalContractList;

    // =========================================================
    // WATCHED ADDRESSES
    // =========================================================
    struct WatchedAddressRecord {
        address account;
        string label;
        string category;
        bool active;
        uint256 createdAt;
        uint256 updatedAt;
    }

    mapping(address => WatchedAddressRecord) public watchedAddresses;
    address[] public watchedAddressList;

    // =========================================================
    // EVENTS
    // =========================================================
    event MasterAccountTransferred(address indexed previousMaster, address indexed newMaster);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event MintingLockedEvent();

    event ProjectMetadataUpdated(address indexed by, uint256 timestamp);
    event InstitutionalBackingUpdated(address indexed by, uint256 timestamp);

    event DocumentAdded(uint256 indexed id, string title, DocumentType docType);
    event DocumentUpdated(uint256 indexed id, string title, bool active);

    event ExternalTokenAdded(address indexed token, string label, string standard);
    event ExternalTokenUpdated(address indexed token, bool active);

    event ExternalContractAdded(address indexed contractAddress, string label, string contractType);
    event ExternalContractUpdated(address indexed contractAddress, bool active);

    event WatchedAddressAdded(address indexed account, string label, string category);
    event WatchedAddressUpdated(address indexed account, bool active);

    event NativeReceived(address indexed from, uint256 amount);
    event NativeWithdrawn(address indexed to, uint256 amount);
    event ForeignTokenRescued(address indexed token, address indexed to, uint256 amount);

    // =========================================================
    // MODIFIERS
    // =========================================================
    modifier onlyMaster() {
        require(msg.sender == masterAccount, "CCC: caller is not master");
        _;
    }

    modifier validAddress(address account) {
        require(account != address(0), "CCC: zero address");
        _;
    }

    // =========================================================
    // CONSTRUCTOR
    // =========================================================
    constructor() ERC20(TOKEN_NAME, TOKEN_SYMBOL) {
        masterAccount = INITIAL_MASTER;
        treasury = INITIAL_MASTER;
        operator = INITIAL_MASTER;

        _grantRole(DEFAULT_ADMIN_ROLE, INITIAL_MASTER);
        _grantRole(PAUSER_ROLE, INITIAL_MASTER);
        _grantRole(MINTER_ROLE, INITIAL_MASTER);
        _grantRole(OPERATOR_ROLE, INITIAL_MASTER);
        _grantRole(TREASURY_ROLE, INITIAL_MASTER);

        _mint(INITIAL_MASTER, MAX_SUPPLY);

        projectMetadata = ProjectMetadata({
            projectName: "Carbon Credit Coin",
            symbolText: "CCC",
            logoURI: "ipfs://CCC_LOGO_URI",
            imageURI: "ipfs://CCC_MAIN_IMAGE_URI",
            websiteURI: "https://carboncreditcoin.example",
            repositoryURI: "https://github.com/your-repo/carbon-credit-coin",
            whitepaperURI: "ipfs://CCC_WHITEPAPER_URI",
            description: "Carbon Credit Coin (CCC) is a digital environmental asset framework with centralized master governance, declarative institutional registry, document hash anchoring, and integrated external asset catalog.",
            jurisdiction: "International / Declarative Registry",
            legalNotice: "This smart contract stores declarative metadata, references and hashes. It does not, by itself, constitute automatic banking, regulatory, custody, audit, certification, market pricing, or legal proof.",
            pricingReferenceText: "1 CCC = US$1.00 declared reference",
            carbonEquivalenceText: "1 CCC = 164 kg of certified carbon credit declared equivalence",
            referencePriceUSD_6: USD_REFERENCE_PER_CCC_6,
            carbonKgPerCCC: KG_CO2_PER_CCC,
            referencePriceActive: true,
            carbonEquivalenceActive: true,
            updatedAt: block.timestamp
        });

        institutionalBacking = InstitutionalBacking({
            backingType: "Carbon Credit Reserve",
            declaredCustodian: "Declared Custodian Registry Entry",
            declaredAuditor: "Declared Audit Registry Entry",
            declaredValidator: "Declared Validation Registry Entry",
            declaredVerificationText: "Declared verification record subject to external documentary confirmation.",
            declaredCertificationText: "Declared certification record subject to external documentary confirmation.",
            declaredJurisdiction: "International / Declarative",
            issueDateText: "Declared by master",
            maturityText: "",
            declaredBackingUSD_6: 20_000_000_000 * 1_000_000,
            declaredCarbonKg: 20_000_000_000 * 164,
            declaredCarbonTons_3: 20_000_000_000 * 164,
            declaredCustodyActive: false,
            declaredAuditActive: false,
            declaredValidationActive: false,
            declaredCertificationActive: false,
            updatedAt: block.timestamp
        });
    }

    // =========================================================
    // ERC20
    // =========================================================
    function decimals() public pure override returns (uint8) {
        return TOKEN_DECIMALS;
    }

    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }

    // =========================================================
    // GOVERNANCE
    // =========================================================
    function transferMasterAccount(address newMaster) external onlyMaster validAddress(newMaster) {
        address previousMaster = masterAccount;
        masterAccount = newMaster;

        _grantRole(DEFAULT_ADMIN_ROLE, newMaster);
        _grantRole(PAUSER_ROLE, newMaster);
        _grantRole(MINTER_ROLE, newMaster);
        _grantRole(OPERATOR_ROLE, newMaster);
        _grantRole(TREASURY_ROLE, newMaster);

        _revokeRole(PAUSER_ROLE, previousMaster);
        _revokeRole(MINTER_ROLE, previousMaster);
        _revokeRole(OPERATOR_ROLE, previousMaster);
        _revokeRole(TREASURY_ROLE, previousMaster);
        _revokeRole(DEFAULT_ADMIN_ROLE, previousMaster);

        if (treasury == previousMaster) {
            treasury = newMaster;
            emit TreasuryUpdated(previousMaster, newMaster);
        }

        if (operator == previousMaster) {
            operator = newMaster;
            emit OperatorUpdated(previousMaster, newMaster);
        }

        emit MasterAccountTransferred(previousMaster, newMaster);
    }

    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) validAddress(newTreasury) {
        address previousTreasury = treasury;
        treasury = newTreasury;
        _grantRole(TREASURY_ROLE, newTreasury);

        if (previousTreasury != newTreasury) {
            _revokeRole(TREASURY_ROLE, previousTreasury);
        }

        emit TreasuryUpdated(previousTreasury, newTreasury);
    }

    function setOperator(address newOperator) external onlyRole(DEFAULT_ADMIN_ROLE) validAddress(newOperator) {
        address previousOperator = operator;
        operator = newOperator;
        _grantRole(OPERATOR_ROLE, newOperator);

        if (previousOperator != newOperator) {
            _revokeRole(OPERATOR_ROLE, previousOperator);
        }

        emit OperatorUpdated(previousOperator, newOperator);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) validAddress(to) {
        require(!mintingLocked, "CCC: minting locked");
        require(totalSupply() + amount <= MAX_SUPPLY, "CCC: max supply exceeded");
        _mint(to, amount);
    }

    function lockMinting() external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintingLocked = true;
        emit MintingLockedEvent();
    }

    // =========================================================
    // ECONOMIC MODEL
    // =========================================================
    function cccToUsdReference6(uint256 cccAmount18) public pure returns (uint256) {
        return (cccAmount18 * USD_REFERENCE_PER_CCC_6) / 1e18;
    }

    function usdReference6ToCcc(uint256 usdAmount6) public pure returns (uint256) {
        return (usdAmount6 * 1e18) / USD_REFERENCE_PER_CCC_6;
    }

    function cccToCarbonKg(uint256 cccAmount18) public pure returns (uint256) {
        return (cccAmount18 * KG_CO2_PER_CCC) / 1e18;
    }

    function carbonKgToCcc(uint256 carbonKg) public pure returns (uint256) {
        return (carbonKg * 1e18) / KG_CO2_PER_CCC;
    }

    function cccToCarbonTons3(uint256 cccAmount18) public pure returns (uint256) {
        uint256 kg = cccToCarbonKg(cccAmount18);
        return (kg * 1000) / KG_PER_TON;
    }

    // =========================================================
    // PROJECT METADATA
    // =========================================================
    function setProjectMetadata(
        string calldata projectName_,
        string calldata symbolText_,
        string calldata logoURI_,
        string calldata imageURI_,
        string calldata websiteURI_,
        string calldata repositoryURI_,
        string calldata whitepaperURI_,
        string calldata description_,
        string calldata jurisdiction_,
        string calldata legalNotice_,
        string calldata pricingReferenceText_,
        string calldata carbonEquivalenceText_,
        uint256 referencePriceUSD_6_,
        uint256 carbonKgPerCCC_,
        bool referencePriceActive_,
        bool carbonEquivalenceActive_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        projectMetadata = ProjectMetadata({
            projectName: projectName_,
            symbolText: symbolText_,
            logoURI: logoURI_,
            imageURI: imageURI_,
            websiteURI: websiteURI_,
            repositoryURI: repositoryURI_,
            whitepaperURI: whitepaperURI_,
            description: description_,
            jurisdiction: jurisdiction_,
            legalNotice: legalNotice_,
            pricingReferenceText: pricingReferenceText_,
            carbonEquivalenceText: carbonEquivalenceText_,
            referencePriceUSD_6: referencePriceUSD_6_,
            carbonKgPerCCC: carbonKgPerCCC_,
            referencePriceActive: referencePriceActive_,
            carbonEquivalenceActive: carbonEquivalenceActive_,
            updatedAt: block.timestamp
        });

        emit ProjectMetadataUpdated(msg.sender, block.timestamp);
    }

    // =========================================================
    // INSTITUTIONAL BACKING
    // =========================================================
    function setInstitutionalBacking(
        string calldata backingType_,
        string calldata declaredCustodian_,
        string calldata declaredAuditor_,
        string calldata declaredValidator_,
        string calldata declaredVerificationText_,
        string calldata declaredCertificationText_,
        string calldata declaredJurisdiction_,
        string calldata issueDateText_,
        string calldata maturityText_,
        uint256 declaredBackingUSD_6_,
        uint256 declaredCarbonKg_,
        uint256 declaredCarbonTons_3_,
        bool declaredCustodyActive_,
        bool declaredAuditActive_,
        bool declaredValidationActive_,
        bool declaredCertificationActive_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        institutionalBacking = InstitutionalBacking({
            backingType: backingType_,
            declaredCustodian: declaredCustodian_,
            declaredAuditor: declaredAuditor_,
            declaredValidator: declaredValidator_,
            declaredVerificationText: declaredVerificationText_,
            declaredCertificationText: declaredCertificationText_,
            declaredJurisdiction: declaredJurisdiction_,
            issueDateText: issueDateText_,
            maturityText: maturityText_,
            declaredBackingUSD_6: declaredBackingUSD_6_,
            declaredCarbonKg: declaredCarbonKg_,
            declaredCarbonTons_3: declaredCarbonTons_3_,
            declaredCustodyActive: declaredCustodyActive_,
            declaredAuditActive: declaredAuditActive_,
            declaredValidationActive: declaredValidationActive_,
            declaredCertificationActive: declaredCertificationActive_,
            updatedAt: block.timestamp
        });

        emit InstitutionalBackingUpdated(msg.sender, block.timestamp);
    }

    // =========================================================
    // DOCUMENTS
    // =========================================================
    function addDocument(
        DocumentType docType_,
        string calldata title_,
        string calldata issuer_,
        string calldata referenceCode_,
        string calldata uri_,
        string calldata contentHashText_,
        bytes32 contentHashBytes32_,
        string calldata description_,
        bool active_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256 newId) {
        _documentIdCounter += 1;
        newId = _documentIdCounter;

        documents[newId] = DocumentRecord({
            id: newId,
            docType: docType_,
            title: title_,
            issuer: issuer_,
            referenceCode: referenceCode_,
            uri: uri_,
            contentHashText: contentHashText_,
            contentHashBytes32: contentHashBytes32_,
            description: description_,
            active: active_,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        documentIds.push(newId);
        emit DocumentAdded(newId, title_, docType_);
    }

    function updateDocument(
        uint256 documentId_,
        DocumentType docType_,
        string calldata title_,
        string calldata issuer_,
        string calldata referenceCode_,
        string calldata uri_,
        string calldata contentHashText_,
        bytes32 contentHashBytes32_,
        string calldata description_,
        bool active_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(documents[documentId_].id != 0, "CCC: document not found");

        DocumentRecord storage doc = documents[documentId_];
        doc.docType = docType_;
        doc.title = title_;
        doc.issuer = issuer_;
        doc.referenceCode = referenceCode_;
        doc.uri = uri_;
        doc.contentHashText = contentHashText_;
        doc.contentHashBytes32 = contentHashBytes32_;
        doc.description = description_;
        doc.active = active_;
        doc.updatedAt = block.timestamp;

        emit DocumentUpdated(documentId_, title_, active_);
    }

    function verifyDocumentHash(bytes32 hash_) external view returns (bool) {
        for (uint256 i = 0; i < documentIds.length; i++) {
            uint256 id = documentIds[i];
            if (documents[id].active && documents[id].contentHashBytes32 == hash_) {
                return true;
            }
        }
        return false;
    }

    // =========================================================
    // EXTERNAL TOKENS / CONTRACTS / WATCHED
    // =========================================================
    function addExternalToken(
        address token_,
        string memory standard_,
        string memory label_,
        bool active_
    )
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(token_)
    {
        if (externalTokens[token_].token == address(0)) {
            externalTokenList.push(token_);
            externalTokens[token_] = ExternalTokenRecord({
                token: token_,
                standard: standard_,
                label: label_,
                active: active_,
                createdAt: block.timestamp,
                updatedAt: block.timestamp
            });
            emit ExternalTokenAdded(token_, label_, standard_);
        } else {
            ExternalTokenRecord storage record = externalTokens[token_];
            record.standard = standard_;
            record.label = label_;
            record.active = active_;
            record.updatedAt = block.timestamp;
            emit ExternalTokenUpdated(token_, active_);
        }
    }

    function addExternalContract(
        address contractAddress_,
        string memory label_,
        string memory contractType_,
        bool active_
    )
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(contractAddress_)
    {
        if (externalContracts[contractAddress_].contractAddress == address(0)) {
            externalContractList.push(contractAddress_);
            externalContracts[contractAddress_] = ExternalContractRecord({
                contractAddress: contractAddress_,
                label: label_,
                contractType: contractType_,
                active: active_,
                createdAt: block.timestamp,
                updatedAt: block.timestamp
            });
            emit ExternalContractAdded(contractAddress_, label_, contractType_);
        } else {
            ExternalContractRecord storage record = externalContracts[contractAddress_];
            record.label = label_;
            record.contractType = contractType_;
            record.active = active_;
            record.updatedAt = block.timestamp;
            emit ExternalContractUpdated(contractAddress_, active_);
        }
    }

    function addWatchedAddress(
        address account_,
        string memory label_,
        string memory category_,
        bool active_
    )
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        validAddress(account_)
    {
        if (watchedAddresses[account_].account == address(0)) {
            watchedAddressList.push(account_);
            watchedAddresses[account_] = WatchedAddressRecord({
                account: account_,
                label: label_,
                category: category_,
                active: active_,
                createdAt: block.timestamp,
                updatedAt: block.timestamp
            });
            emit WatchedAddressAdded(account_, label_, category_);
        } else {
            WatchedAddressRecord storage record = watchedAddresses[account_];
            record.label = label_;
            record.category = category_;
            record.active = active_;
            record.updatedAt = block.timestamp;
            emit WatchedAddressUpdated(account_, active_);
        }
    }

    // =========================================================
    // BOOTSTRAP
    // =========================================================
    function bootstrapCoreCatalog() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!bootstrapExecuted, "CCC: bootstrap already executed");
        bootstrapExecuted = true;

        // Tokens externos
        addExternalToken(0xdAC17F958D2ee523a2206206994597C13D831ec7, "ERC20", "Tether USD (USDT)", true);
        addExternalToken(0x495f947276749Ce646f68AC8c248420045cb7b5e, "ERC1155", "OpenSea Shared Storefront", true);
        addExternalToken(0x58b6A8A3302369DAEc383334672404Ee733aB239, "ERC20", "Livepeer Token (LPT)", true);
        addExternalToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, "ERC20", "USD Coin (USDC)", true);
        addExternalToken(0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE, "ERC20", "Shiba Inu (SHIB)", true);
        addExternalToken(0xC12D1c73eE7DC3615BA4e37E4ABFdbDDFA38907E, "ERC20", "KickToken (KICK)", true);
        addExternalToken(0x426CA1eA2406c07d75Db9585F22781c096e3d0E0, "ERC20", "External Token 01", true);
        addExternalToken(0xc92e74b131D7b1D46E60e07F3FaE5d8877Dd03F0, "ERC20", "External Token 02", true);
        addExternalToken(0x7B2f9706CD8473B4F5B7758b0171a9933Fc6C4d6, "ERC20", "External Token 03", true);
        addExternalToken(0xf230b790E05390FC8295F4d3F60332c93BEd42e2, "ERC20", "External Token 04", true);
        addExternalToken(0x519475b31653E46D20cD09F9FdcF3B12BDAcB4f5, "ERC20", "External Token 05", true);
        addExternalToken(0x52903256dd18D85c2Dc4a6C999907c9793eA61E3, "ERC20", "External Token 06", true);
        addExternalToken(0xa3EE21C306A700E682AbCdfe9BaA6A08F3820419, "ERC20", "External Token 07", true);
        addExternalToken(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, "ERC20", "Wrapped Ether (WETH)", true);
        addExternalToken(0xab95E915c123fdEd5BDfB6325e35ef5515F1EA69, "ERC20", "External Token 08", true);
        addExternalToken(0x6130a0C4eB9eA062fC10df5C564149Da1d86565F, "ERC20", "External Token 09", true);
        addExternalToken(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85, "ERC20", "External Token 10", true);
        addExternalToken(0xd26114cd6EE289AccF82350c8d8487fedB8A0C07, "ERC20", "OmiseGO (OMG)", true);
        addExternalToken(0x514910771AF9Ca656af840dff83E8264EcF986CA, "ERC20", "Chainlink (LINK)", true);
        addExternalToken(0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0, "ERC20", "Polygon (MATIC)", true);
        addExternalToken(0xfaaFDc07907ff5120a76b34b731b278c38d6043C, "ERC20", "External Token 11", true);
        addExternalToken(0x6B175474E89094C44Da98b954EedeAC495271d0F, "ERC20", "Dai Stablecoin (DAI)", true);
        addExternalToken(0xF3e014fE81267870624132ef3A646B8E83853a96, "ERC20", "External Token 12", true);
        addExternalToken(0x151BC71a40c56C7cB3317d86996fd0b4fF9bD907, "ERC20", "External Token 13", true);
        addExternalToken(0xD736915F7d9F70a0F1837F90aa7b437264C20dc0, "ERC20", "External Token 14", true);
        addExternalToken(0xA0b73E1Ff0B80914AB6fe0444E65848C4C34450b, "ERC20", "External Token 15", true);
        addExternalToken(0xa342f5D851E866E18ff98F351f2c6637f4478dB5, "ERC20", "External Token 16", true);
        addExternalToken(0xD4307E0acD12CF46fD6cf93BC264f5D5D1598792, "ERC20", "External Token 17", true);
        addExternalToken(0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39, "ERC20", "HEX", true);

        // Contratos externos
        addExternalContract(0x2170ed0880ac9a755fd29b2688956bd959f933f8, "External Contract A", "ERC20/Bridge Asset", true);
        addExternalContract(0xf3162950df0b4ba17a65fb7a5dd7dff3c91ef190, "External Contract B", "External Contract", true);
        addExternalContract(0x1b1979f530c0a93c68f57f412c97bf0fd5e69046, "External Contract C", "External Contract", true);
        addExternalContract(0x84d7cd12a950e1260ec9eaa96eb5dce4417be1cf, "External Contract D", "External Contract", true);
        addExternalContract(0x372101cf57206ab06c924012df905e82a66ec71a, "External Contract E", "External Contract", true);
        addExternalContract(0xba12222222228d8ba445958a75a0704d566bf2c8, "Balancer Vault", "Vault", true);
        addExternalContract(0x109830a1aaad605bbf02a9dfa7b0b92ec2fb7daa, "External Contract F", "External Contract", true);
        addExternalContract(0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0, "External Contract G", "External Contract", true);
        addExternalContract(0x5a52e96bacdabb82fd05763e25335261b270efcb, "External Contract H", "External Contract", true);
        addExternalContract(0x7473670070f2adeee5edb9e3f6e1ee6480e66de1, "External Contract I", "External Contract", true);
        addExternalContract(0x835678a611b28684005a5e2233695fb6cbbb0007, "External Contract J", "External Contract", true);
        addExternalContract(0xf977814e90da44bfa03b6295a0616a897441acec, "External Contract K", "Custodial/Exchange Address", true);
        addExternalContract(0x6c96de32cea08842dcc4058c14d3aaad7fa41dee, "External Contract L", "External Contract", true);

        // Endereços monitorados
        addWatchedAddress(INITIAL_MASTER, "CCC Master Wallet", "master", true);
        addWatchedAddress(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, "Watched Wallet 01", "wallet", true);
        addWatchedAddress(0x15d34aaf54267db7d7c367839aaf71a00a2c6a65, "Watched Wallet 02", "wallet", true);
    }

    // =========================================================
    // TREASURY
    // =========================================================
    receive() external payable {
        emit NativeReceived(msg.sender, msg.value);
    }

    function withdrawNative(address payable to, uint256 amount)
        external
        onlyRole(TREASURY_ROLE)
        nonReentrant
        validAddress(to)
    {
        require(address(this).balance >= amount, "CCC: insufficient native balance");
        (bool success, ) = to.call{value: amount}("");
        require(success, "CCC: native transfer failed");
        emit NativeWithdrawn(to, amount);
    }

    function rescueForeignToken(address token, address to, uint256 amount)
        external
        onlyRole(TREASURY_ROLE)
        nonReentrant
        validAddress(token)
        validAddress(to)
    {
        require(token != address(this), "CCC: cannot rescue CCC");
        IERC20(token).safeTransfer(to, amount);
        emit ForeignTokenRescued(token, to, amount);
    }

    // =========================================================
    // VIEWS
    // =========================================================
    function documentsCount() external view returns (uint256) {
        return documentIds.length;
    }

    function externalTokensCount() external view returns (uint256) {
        return externalTokenList.length;
    }

    function externalContractsCount() external view returns (uint256) {
        return externalContractList.length;
    }

    function watchedAddressesCount() external view returns (uint256) {
        return watchedAddressList.length;
    }

    function getSummary()
        external
        view
        returns (
            string memory name_,
            string memory symbol_,
            uint256 totalSupply_,
            uint256 maxSupply_,
            address master_,
            address treasury_,
            address operator_,
            bool paused_,
            bool mintLocked_,
            bool bootstrapDone_,
            uint256 docsCount_,
            uint256 extTokensCount_,
            uint256 extContractsCount_,
            uint256 watchedCount_
        )
    {
        return (
            name(),
            symbol(),
            totalSupply(),
            MAX_SUPPLY,
            masterAccount,
            treasury,
            operator,
            paused(),
            mintingLocked,
            bootstrapExecuted,
            documentIds.length,
            externalTokenList.length,
            externalContractList.length,
            watchedAddressList.length
        );
    }
}
