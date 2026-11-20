#!/usr/bin/env node
/**
 * Experimental: plan idempotent Recycle contract and vehicle seed SQL.
 * Does not open a database and does not read secrets.
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

type Material = {
  id: string;
  name: string;
  unit: string;
};

type Detail = {
  id: string;
  materialId: string;
  materialName: string;
  unit: string;
  usage: string;
  quantityKg: string;
  unitPrice: string;
};

type Transporter = {
  id: string;
  companyName: string;
};

type Contract = {
  id: string;
  contractNo: string;
  signDate: string;
  producerName: string;
  buyerName: string;
  shipAddress: string;
  transporters: Transporter[];
  details: Detail[];
};

type Vehicle = {
  id: string;
  plateNumber: string;
  transporterName: string;
  contactPhone: string;
  tareWeightKg: string;
  isEnabled: boolean;
};

type Seed = {
  marker: string;
  concurrencyStamp: string;
  materials: Material[];
  contracts: Contract[];
  vehicles: Vehicle[];
};

const limits = {
  name: 200,
  address: 500,
  phone: 32,
  plate: 32,
  contractNo: 64,
  usage: 200,
  unit: 16,
  stamp: 40,
};

const guidPattern =
  /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

function arg(name: string): string {
  const index = process.argv.indexOf(name);
  const value = index >= 0 ? process.argv[index + 1] : "";
  if (!value) {
    throw new Error(`missing ${name}`);
  }
  return value;
}

function requireText(value: string, max: number, field: string): string {
  const text = value.trim();
  if (text.length === 0 || text.length > max) {
    throw new Error(`field ${field} length`);
  }
  return text;
}

function optionalText(value: string | undefined, max: number, field: string): string {
  const text = (value ?? "").trim();
  if (text.length > max) {
    throw new Error(`field ${field} length`);
  }
  return text;
}

function requireGuid(value: string, field: string): string {
  if (!guidPattern.test(value)) {
    throw new Error(`field ${field} guid`);
  }
  return value.toLowerCase();
}

function requireDate(value: string): string {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value) || Number.isNaN(Date.parse(`${value}T00:00:00Z`))) {
    throw new Error("signDate");
  }
  return value;
}

function scaled(text: string, scale: number, field: string): bigint {
  const match = /^(\d+)(?:\.(\d+))?$/.exec(text.trim());
  if (!match) {
    throw new Error(`field ${field} decimal`);
  }
  const fraction = match[2] ?? "";
  if (fraction.length > scale) {
    throw new Error(`field ${field} scale`);
  }
  return BigInt(match[1] + fraction.padEnd(scale, "0"));
}

function money(quantityKg: string, unitPrice: string): string {
  const product = scaled(quantityKg, 9, "quantityKg") * scaled(unitPrice, 9, "unitPrice");
  const remainder = product % 10n ** 16n;
  if (remainder !== 0n) {
    throw new Error("amount scale");
  }
  const cents = product / 10n ** 16n;
  const negative = cents < 0n;
  const abs = negative ? -cents : cents;
  const digits = abs.toString().padStart(3, "0");
  return `${digits.slice(0, -2)}.${digits.slice(-2)}`;
}

function quote(value: string): string {
  return `N'${value.replaceAll("'", "''")}'`;
}

function sqlText(value: string): string {
  return value.trim() === "" ? "NULL" : quote(value);
}

function guidList(ids: string[]): string {
  return ids.map((id) => `'${id}'`).join(", ");
}

function loadSeed(path: string, proId: string): Seed {
  const seed = JSON.parse(readFileSync(path, "utf8")) as Seed;
  requireGuid(proId, "proId");
  requireText(seed.marker, 80, "marker");
  if (seed.concurrencyStamp.length === 0 || seed.concurrencyStamp.length > limits.stamp) {
    throw new Error("concurrencyStamp");
  }
  if (seed.contracts.length === 0 || seed.vehicles.length === 0 || seed.materials.length === 0) {
    throw new Error("empty seed");
  }
  const ids = new Set<string>();
  const contractNos = new Set<string>();
  const plates = new Set<string>();
  const materialNames = new Map<string, string>();
  const claim = (id: string, field: string) => {
    const key = requireGuid(id, field);
    if (ids.has(key)) {
      throw new Error(`duplicate ${field}`);
    }
    ids.add(key);
  };
  for (const material of seed.materials) {
    claim(material.id, "material.id");
    const name = requireText(material.name, limits.name, "material.name");
    requireText(material.unit, limits.unit, "material.unit");
    if (materialNames.has(name)) {
      throw new Error("duplicate material name");
    }
    materialNames.set(name, material.id);
  }
  for (const contract of seed.contracts) {
    claim(contract.id, "contract.id");
    const contractNo = requireText(contract.contractNo, limits.contractNo, "contractNo");
    if (contractNos.has(contractNo)) {
      throw new Error("duplicate contractNo");
    }
    contractNos.add(contractNo);
    requireDate(contract.signDate);
    optionalText(contract.producerName, limits.name, "producerName");
    requireText(contract.buyerName, limits.name, "buyerName");
    requireText(contract.shipAddress, limits.address, "shipAddress");
    if (contract.details.length === 0) {
      throw new Error("contract materials");
    }
    for (const detail of contract.details) {
      claim(detail.id, "materialLink.id");
      const materialId = requireGuid(detail.materialId, "materialId");
      const materialName = requireText(detail.materialName, limits.name, "materialName");
      if (materialNames.get(materialName) !== materialId) {
        throw new Error("material link");
      }
      requireText(detail.unit, limits.unit, "unit");
      optionalText(detail.usage, limits.usage, "usage");
      money(detail.quantityKg, detail.unitPrice);
    }
    for (const transporter of contract.transporters) {
      claim(transporter.id, "transporter.id");
      requireText(transporter.companyName, limits.name, "companyName");
    }
  }
  for (const vehicle of seed.vehicles) {
    claim(vehicle.id, "vehicle.id");
    const plate = requireText(vehicle.plateNumber, limits.plate, "plateNumber");
    if (plates.has(plate)) {
      throw new Error("duplicate plate");
    }
    plates.add(plate);
    optionalText(vehicle.transporterName, limits.name, "transporterName");
    optionalText(vehicle.contactPhone, limits.phone, "contactPhone");
    scaled(vehicle.tareWeightKg, 9, "tareWeightKg");
    if (typeof vehicle.isEnabled !== "boolean") {
      throw new Error("isEnabled");
    }
  }
  return seed;
}

function countSelect(seed: Seed, proId: string): string {
  const contractIds = guidList(seed.contracts.map((row) => row.id));
  const contractNos = seed.contracts.map((row) => quote(row.contractNo)).join(", ");
  const vehicleIds = guidList(seed.vehicles.map((row) => row.id));
  const plates = seed.vehicles.map((row) => quote(row.plateNumber)).join(", ");
  return `
SELECT CONCAT('gov5020=', COUNT_BIG(*)) FROM dbo.GovProjects
 WHERE SourceProId = '${proId}' AND ProductCode = 5020 AND IsDeleted = 0
UNION ALL
SELECT CONCAT('contractMatch=', COUNT_BIG(*)) FROM dbo.RecycleContracts
 WHERE ProId = '${proId}' AND IsDeleted = 0 AND ContractNo IN (${contractNos}) AND Id IN (${contractIds})
UNION ALL
SELECT CONCAT('contractConflict=', COUNT_BIG(*)) FROM dbo.RecycleContracts
 WHERE IsDeleted = 0 AND (
      (ProId = '${proId}' AND ContractNo IN (${contractNos}) AND Id NOT IN (${contractIds}))
   OR (Id IN (${contractIds}) AND ProId <> '${proId}')
 )
UNION ALL
SELECT CONCAT('vehicleMatch=', COUNT_BIG(*)) FROM dbo.RecycleVehicles
 WHERE ProId = '${proId}' AND IsDeleted = 0 AND PlateNumber IN (${plates}) AND Id IN (${vehicleIds})
UNION ALL
SELECT CONCAT('vehicleConflict=', COUNT_BIG(*)) FROM dbo.RecycleVehicles
 WHERE IsDeleted = 0 AND (
      (ProId = '${proId}' AND PlateNumber IN (${plates}) AND Id NOT IN (${vehicleIds}))
   OR (Id IN (${vehicleIds}) AND ProId <> '${proId}')
 )
UNION ALL
SELECT CONCAT('detailCount=', COUNT_BIG(*)) FROM dbo.RecycleContractMaterials
 WHERE ProId = '${proId}' AND IsDeleted = 0 AND ContractId IN (${contractIds})
UNION ALL
SELECT CONCAT('transporterCount=', COUNT_BIG(*)) FROM dbo.RecycleContractTransporters
 WHERE ProId = '${proId}' AND IsDeleted = 0 AND ContractId IN (${contractIds});
`.trim();
}

function applyBody(seed: Seed, proId: string): string {
  const extra = quote(JSON.stringify({ Seed: seed.marker }));
  const stamp = quote(seed.concurrencyStamp);
  const contractIds = guidList(seed.contracts.map((row) => row.id));
  const lines: string[] = [
    "SET XACT_ABORT ON;",
    "SET NOCOUNT ON;",
    "BEGIN TRAN;",
    `IF (SELECT COUNT_BIG(*) FROM dbo.GovProjects WHERE SourceProId = '${proId}' AND ProductCode = 5020 AND IsDeleted = 0) <> 1 THROW 51000, 'bound-5020-count', 1;`,
  ];
  lines.push(
    `IF (SELECT COUNT_BIG(*) FROM dbo.RecycleContracts WHERE IsDeleted = 0 AND ((ProId = '${proId}' AND ContractNo IN (${seed.contracts.map((row) => quote(row.contractNo)).join(", ")}) AND Id NOT IN (${contractIds})) OR (Id IN (${contractIds}) AND ProId <> '${proId}'))) <> 0 THROW 51001, 'contract-conflict', 1;`,
  );
  const vehicleIds = guidList(seed.vehicles.map((row) => row.id));
  lines.push(
    `IF (SELECT COUNT_BIG(*) FROM dbo.RecycleVehicles WHERE IsDeleted = 0 AND ((ProId = '${proId}' AND PlateNumber IN (${seed.vehicles.map((row) => quote(row.plateNumber)).join(", ")}) AND Id NOT IN (${vehicleIds})) OR (Id IN (${vehicleIds}) AND ProId <> '${proId}'))) <> 0 THROW 51002, 'vehicle-conflict', 1;`,
  );
  for (const contract of seed.contracts) {
    lines.push(`
IF EXISTS (SELECT 1 FROM dbo.RecycleContracts WHERE Id = '${contract.id}')
BEGIN
  UPDATE dbo.RecycleContracts
     SET ContractNo = ${quote(contract.contractNo)},
         SignDate = '${contract.signDate}T00:00:00',
         ProducerCompanyId = NULL,
         ProducerName = ${sqlText(contract.producerName)},
         BuyerCompanyId = NULL,
         BuyerName = ${quote(contract.buyerName)},
         ShipAddress = ${quote(contract.shipAddress)},
         SyncStatus = 0,
         LastSyncedAt = NULL,
         ExtraProperties = ${extra},
         ConcurrencyStamp = ${stamp},
         LastModificationTime = SYSUTCDATETIME(),
         IsDeleted = 0,
         DeleterId = NULL,
         DeletionTime = NULL
   WHERE Id = '${contract.id}' AND ProId = '${proId}';
  IF @@ROWCOUNT <> 1 THROW 51003, 'contract-update', 1;
END
ELSE
BEGIN
  INSERT INTO dbo.RecycleContracts (
    Id, ProId, ContractNo, SignDate, ProducerCompanyId, ProducerName, BuyerCompanyId, BuyerName,
    ShipAddress, SyncStatus, LastSyncedAt, ExtraProperties, ConcurrencyStamp, CreationTime,
    CreatorId, LastModificationTime, LastModifierId, IsDeleted, DeleterId, DeletionTime)
  VALUES (
    '${contract.id}', '${proId}', ${quote(contract.contractNo)}, '${contract.signDate}T00:00:00',
    NULL, ${sqlText(contract.producerName)}, NULL, ${quote(contract.buyerName)},
    ${quote(contract.shipAddress)}, 0, NULL, ${extra}, ${stamp}, SYSUTCDATETIME(),
    NULL, NULL, NULL, 0, NULL, NULL);
END`.trim());
  }
  for (const material of seed.materials) {
    lines.push(`
IF EXISTS (SELECT 1 FROM dbo.RecycleMaterials WHERE Id = '${material.id}' AND IsDeleted = 0 AND ProId <> '${proId}')
  THROW 51005, 'material-id-conflict', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.RecycleMaterials WHERE ProId = '${proId}' AND Name = ${quote(material.name)} AND IsDeleted = 0)
BEGIN
  IF EXISTS (SELECT 1 FROM dbo.RecycleMaterials WHERE Id = '${material.id}')
    THROW 51005, 'material-id-conflict', 1;
  INSERT INTO dbo.RecycleMaterials (
    Id, ProId, Name, Code, DefaultUsage, Unit, IsEnabled, ExtraProperties, ConcurrencyStamp,
    CreationTime, CreatorId, LastModificationTime, LastModifierId, IsDeleted, DeleterId, DeletionTime)
  VALUES (
    '${material.id}', '${proId}', ${quote(material.name)}, NULL, NULL, ${quote(material.unit)}, 1,
    ${extra}, ${stamp}, SYSUTCDATETIME(), NULL, NULL, NULL, 0, NULL, NULL);
END`.trim());
  }
  lines.push(`DELETE FROM dbo.RecycleContractMaterials WHERE ProId = '${proId}' AND ContractId IN (${contractIds});`);
  lines.push(`DELETE FROM dbo.RecycleContractTransporters WHERE ProId = '${proId}' AND ContractId IN (${contractIds});`);
  for (const contract of seed.contracts) {
    for (const detail of contract.details) {
      const amount = money(detail.quantityKg, detail.unitPrice);
      lines.push(`
INSERT INTO dbo.RecycleContractMaterials (
  Id, ProId, ContractId, MaterialId, MaterialName, Unit, Usage, QuantityKg, UnitPrice, Amount,
  CreationTime, CreatorId, LastModificationTime, LastModifierId, IsDeleted, DeleterId, DeletionTime)
VALUES (
  '${detail.id}', '${proId}', '${contract.id}', (SELECT TOP (1) Id FROM dbo.RecycleMaterials WHERE ProId = '${proId}' AND Name = ${quote(detail.materialName)} AND IsDeleted = 0 ORDER BY CreationTime, Id), ${quote(detail.materialName)}, ${quote(detail.unit)},
  ${sqlText(detail.usage)}, ${detail.quantityKg}, ${detail.unitPrice}, ${amount},
  SYSUTCDATETIME(), NULL, NULL, NULL, 0, NULL, NULL);`.trim());
    }
    for (const transporter of contract.transporters) {
      lines.push(`
INSERT INTO dbo.RecycleContractTransporters (
  Id, ProId, ContractId, CompanyId, CompanyName, CreationTime, CreatorId,
  LastModificationTime, LastModifierId, IsDeleted, DeleterId, DeletionTime)
VALUES (
  '${transporter.id}', '${proId}', '${contract.id}', NULL, ${quote(transporter.companyName)},
  SYSUTCDATETIME(), NULL, NULL, NULL, 0, NULL, NULL);`.trim());
    }
  }
  for (const vehicle of seed.vehicles) {
    const enabled = vehicle.isEnabled ? 1 : 0;
    lines.push(`
IF EXISTS (SELECT 1 FROM dbo.RecycleVehicles WHERE Id = '${vehicle.id}')
BEGIN
  UPDATE dbo.RecycleVehicles
     SET PlateNumber = ${quote(vehicle.plateNumber)},
         OwnerName = NULL,
         TransporterName = ${sqlText(vehicle.transporterName)},
         ContactPhone = ${sqlText(vehicle.contactPhone)},
         TareWeightKg = ${vehicle.tareWeightKg},
         IsEnabled = ${enabled},
         ExtraProperties = ${extra},
         ConcurrencyStamp = ${stamp},
         LastModificationTime = SYSUTCDATETIME(),
         IsDeleted = 0,
         DeleterId = NULL,
         DeletionTime = NULL
   WHERE Id = '${vehicle.id}' AND ProId = '${proId}';
  IF @@ROWCOUNT <> 1 THROW 51004, 'vehicle-update', 1;
END
ELSE
BEGIN
  INSERT INTO dbo.RecycleVehicles (
    Id, ProId, PlateNumber, OwnerName, TransporterName, ContactPhone, TareWeightKg, IsEnabled,
    ExtraProperties, ConcurrencyStamp, CreationTime, CreatorId, LastModificationTime, LastModifierId,
    IsDeleted, DeleterId, DeletionTime)
  VALUES (
    '${vehicle.id}', '${proId}', ${quote(vehicle.plateNumber)}, NULL, ${sqlText(vehicle.transporterName)},
    ${sqlText(vehicle.contactPhone)}, ${vehicle.tareWeightKg}, ${enabled}, ${extra}, ${stamp},
    SYSUTCDATETIME(), NULL, NULL, NULL, 0, NULL, NULL);
END`.trim());
  }
  lines.push("COMMIT;");
  lines.push(countSelect(seed, proId));
  return lines.join("\n");
}

const fixturePath = arg("--fixture");
const proId = requireGuid(arg("--proId"), "proId");
const outDir = arg("--outDir");
const seed = loadSeed(fixturePath, proId);
mkdirSync(outDir, { recursive: true });
const detailCount = seed.contracts.reduce((sum, row) => sum + row.details.length, 0);
const transporterCount = seed.contracts.reduce((sum, row) => sum + row.transporters.length, 0);
const plan = {
  marker: seed.marker,
  sourceProId: proId,
  contracts: seed.contracts.map((row) => row.contractNo),
  vehicles: seed.vehicles.map((row) => row.plateNumber),
  planned: {
    contracts: seed.contracts.length,
    vehicles: seed.vehicles.length,
    details: detailCount,
    transporters: transporterCount,
  },
};
writeFileSync(join(outDir, "plan.json"), `${JSON.stringify(plan, null, 2)}\n`, "utf8");
writeFileSync(join(outDir, "seed.preview.sql"), `${countSelect(seed, proId)}\n`, "utf8");
writeFileSync(join(outDir, "seed.apply.sql"), `${applyBody(seed, proId)}\n`, "utf8");
console.log(JSON.stringify(plan.planned));
