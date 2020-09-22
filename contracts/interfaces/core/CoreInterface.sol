pragma solidity ^0.5.12;

interface CoreInterface {

    /* Module manipulation events */

    event ModuleAdded(string name, address indexed module);

    event ModuleRemoved(string name, address indexed module);

    event ModuleReplaced(string name, address indexed from, address indexed to);


    /* Functions */

    function set(string calldata  _name, address _module, bool _constant) external;

    function setMetadata(string calldata _name, string  calldata _description) external;

    function remove(string calldata _name) external;
    
    function contains(address _module)  external view returns (bool);

    function size() external view returns (uint);

    function isConstant(string calldata _name) external view returns (bool);

    function get(string calldata _name)  external view returns (address);

    function getName(address _module)  external view returns (string memory);

    function first() external view returns (address);

    function next(address _current)  external view returns (address);
}