// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Chemical Properties Library
 * @dev Handles chemical property calculations for boron group elements
 */
library ChemicalProperties {
    uint256 constant PRECISION = 1e18;
    uint256 constant BORON_MELTING_POINT = 2076;  // Celsius
    uint256 constant STANDARD_MELTING_POINT = 1000;  // Reference point
    
    struct ElementProperties {
        uint256 meltingPoint;        // In Celsius
        uint256 electronConfig;      // Energy state factor
        uint256 crystalStructure;    // Structure type (1: α-rhombohedral, 2: β-rhombohedral)
        uint256 purityLevel;         // Required purity (percentage * PRECISION)
    }
    
    struct ProcessingFactors {
        uint256 extractionEnergy;    // Base energy requirement
        uint256 processingEnergy;    // Additional processing energy
        uint256 purityFactor;        // Energy increase per purity level
        uint256 structureFactor;     // Crystal structure impact
    }
    
    /**
     * @dev Calculate energy requirement based on chemical properties
     */
    function calculateEnergyRequirement(
        ElementProperties memory props,
        ProcessingFactors memory factors
    ) internal pure returns (uint256) {
        // Calculate melting point impact
        uint256 meltingPointFactor = (props.meltingPoint * PRECISION) / STANDARD_MELTING_POINT;
        
        // Calculate electron configuration impact
        uint256 electronFactor = (props.electronConfig * factors.extractionEnergy) / PRECISION;
        
        // Calculate crystal structure impact
        uint256 structureEnergy = factors.extractionEnergy * factors.structureFactor * props.crystalStructure / PRECISION;
        
        // Calculate purity impact
        uint256 purityEnergy = factors.processingEnergy * props.purityLevel * factors.purityFactor / (PRECISION * PRECISION);
        
        return (meltingPointFactor * (electronFactor + structureEnergy + purityEnergy)) / PRECISION;
    }
    
    /**
     * @dev Calculate property-based value
     */
    function calculatePropertyValue(
        ElementProperties memory props
    ) internal pure returns (uint256) {
        uint256 baseValue = (props.meltingPoint * PRECISION) / STANDARD_MELTING_POINT;
        uint256 configValue = props.electronConfig;
        uint256 structureValue = props.crystalStructure * PRECISION / 2;
        
        return (baseValue + configValue + structureValue) * props.purityLevel / PRECISION;
    }
    
    /**
     * @dev Calculate mining difficulty adjustment based on properties
     */
    function calculateDifficultyAdjustment(
        ElementProperties memory props,
        uint256 currentDifficulty
    ) internal pure returns (uint256) {
        uint256 propertyValue = calculatePropertyValue(props);
        return (currentDifficulty * propertyValue) / PRECISION;
    }
    
    /**
     * @dev Get default boron properties
     */
    function getDefaultBoronProperties() internal pure returns (ElementProperties memory) {
        return ElementProperties({
            meltingPoint: BORON_MELTING_POINT,
            electronConfig: PRECISION, // [He] 2s² 2p¹
            crystalStructure: 1,      // α-rhombohedral
            purityLevel: PRECISION    // 100%
        });
    }
    
    /**
     * @dev Get default processing factors
     */
    function getDefaultProcessingFactors() internal pure returns (ProcessingFactors memory) {
        return ProcessingFactors({
            extractionEnergy: 500 * PRECISION,  // 500 kWh base
            processingEnergy: 200 * PRECISION,  // 200 kWh additional
            purityFactor: PRECISION / 10,       // 10% increase per purity level
            structureFactor: PRECISION / 5      // 20% impact from structure
        });
    }
    
    /**
     * @dev Validate chemical properties
     */
    function validateProperties(
        ElementProperties memory props
    ) internal pure returns (bool) {
        require(props.meltingPoint > 0, "Invalid melting point");
        require(props.electronConfig > 0, "Invalid electron config");
        require(props.crystalStructure > 0 && props.crystalStructure <= 2, "Invalid structure");
        require(props.purityLevel > 0 && props.purityLevel <= PRECISION, "Invalid purity");
        return true;
    }
}
