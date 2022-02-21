
import os
from typing import Optional

import pandas as pd
from sklearn.model_selection import train_test_split
from torchvision.io import read_image  # may want to replace with self.read_image for e.g. FITS, Liza
import torch
from torch.utils.data import DataLoader, Dataset
from torchvision import transforms
import pytorch_lightning as pl

import albumentations as A
from albumentations.pytorch import ToTensorV2

# https://pytorch-lightning.readthedocs.io/en/stable/extensions/datamodules.html

# for now, all this really does is split a dataframe and apply no transforms
class DECALSDR8DataModule(pl.LightningDataModule):
    def __init__(
        self,
        schema,
        # provide full catalog for automatic split, or...
        catalog=None,
        # provide train/val/test catalogs for your own previous split
        train_catalog=None,
        val_catalog=None,
        test_catalog=None,
        greyscale=True,
        batch_size=256,
        num_workers=16,
        seed=42
        ):
        super().__init__()

        if catalog is not None:  # catalog provided, should not also provide explicit split catalogs
            assert train_catalog is None
            assert val_catalog is None
            assert test_catalog is None
        else:  # catalog not provided, must provide explicit split catalogs
            assert train_catalog is not None
            assert val_catalog is not None
            assert test_catalog is not None

        self.schema = schema

        self.catalog = catalog
        self.train_catalog = train_catalog
        self.val_catalog = val_catalog
        self.test_catalog = test_catalog

        self.batch_size = batch_size
        self.num_workers = num_workers
        self.seed = seed

        if greyscale:
            transforms_to_apply = [transforms.Grayscale()]
        else:
            transforms_to_apply = []

        transforms_to_apply += [
            # transforms.RandomCrop(size=(224, 224)),
            transforms.RandomResizedCrop(
                size=(224, 224),  # after crop then resize
                scale=(0.7, 0.8),  # crop factor
                ratio=(0.9, 1.1),  # crop aspect ratio
                interpolation=transforms.InterpolationMode.BILINEAR),  # new aspect ratio
            transforms.RandomHorizontalFlip(),
            transforms.RandomVerticalFlip(),
            transforms.RandomRotation(degrees=90., interpolation=transforms.InterpolationMode.BILINEAR),
            # transforms.ToTensor()  # smth in here is already making it a tensor
            transforms.ConvertImageDtype(torch.float)
            # TODO maybe normalise further? already 0-1 by default it seems which is perfect tbh
        ]

        self.transform = transforms.Compose(transforms_to_apply)  # TODO more

    def prepare_data(self):
        pass   # could include some basic checks

    def setup(self, stage: Optional[str] = None):

        if self.catalog is not None:
            self.train_catalog, hidden_catalog = train_test_split(
                self.catalog, train_size=0.7, random_state=self.seed
            )
            self.val_catalog, self.test_catalog = train_test_split(
                hidden_catalog, train_size=1./3., random_state=self.seed
            )
            del hidden_catalog
        else:
            assert self.train_catalog is not None
            assert self.val_catalog is not None
            assert self.test_catalog is not None

        # Assign train/val datasets for use in dataloaders
        if stage == "fit" or stage is None:
            self.train_dataset = DECALSDR8Dataset(
                catalog=self.train_catalog, schema=self.schema, transform=self.transform
            )
            self.val_dataset = DECALSDR8Dataset(
                catalog=self.val_catalog, schema=self.schema, transform=self.transform
            )

        # Assign test dataset for use in dataloader(s)
        if stage == "test" or stage is None:
            self.test_dataset = DECALSDR8Dataset(
                catalog=self.test_catalog, schema=self.schema, transform=self.transform
            )


    def train_dataloader(self):
        return DataLoader(self.train_dataset, batch_size=self.batch_size, shuffle=True, num_workers=self.num_workers, pin_memory=True, persistent_workers=True)

    def val_dataloader(self):
        return DataLoader(self.val_dataset, batch_size=self.batch_size, num_workers=self.num_workers, pin_memory=True, persistent_workers=True)

    def test_dataloader(self):
        return DataLoader(self.test_dataset, batch_size=self.batch_size, num_workers=self.num_workers, pin_memory=True, persistent_workers=True)



# https://pytorch.org/tutorials/beginner/basics/data_tutorial.html
class DECALSDR8Dataset(Dataset):
    def __init__(self, catalog: pd.DataFrame, schema, transform=None, target_transform=None):
        # catalog should be split already
        # should have correct image locations under file_loc
        self.catalog = catalog
        self.schema = schema
        self.transform = transform
        self.target_transform = target_transform

    def __len__(self):
        return len(self.catalog)

    def __getitem__(self, idx):
        galaxy = self.catalog.iloc[idx]
        img_path = galaxy['file_loc']
        image = read_image(img_path)  # torchvision.io.read_image
        label = get_galaxy_label(galaxy, self.schema)

        if self.transform:
            image = self.transform(image)

        if self.target_transform:
            label = self.target_transform(label)

        return image, label

# import logging

def get_galaxy_label(galaxy, schema):
    return galaxy[schema.label_cols].values.astype(int)
    # logging.info(votes)
    # return torch.from_numpy(votes)
