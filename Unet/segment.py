import h5py
import os
import math
import torch
import torch.nn.functional as F
import numpy as np
from tqdm import tqdm
import nibabel as nib
from Unet.Unet import UNet

# 四种模态的mri图像
modalities = ('FLAIR', 'T1GD', 'T1', 'T2')

# train
train_set = {
    'root': './Unet/data/',  # 四个模态数据所在地址
    'out': './Unet/dataset/',  # 预处理输出地址
    'flist': 'data.txt',  # 训练集名单（有标签）
}


def process_h5(path, out_path):
    """ Save the data with dtype=float32.
        z-score is used but keep the background with zero! """

    # 堆叠四种模态的图像
    images = np.stack([(nib.load(path + modal + '.nii')).get_fdata() for modal in modalities], 0)
    # 数据类型转换
    images = images.astype(np.float32)
    case_name = path.split('/')[-1]

    path = os.path.join(out_path, case_name)
    path = path.replace('/', "\\")
    output = path + 'mri_norm2.h5'
    # 对第一个通道求和，如果四个模态都为0，则标记为背景(False)
    mask = images.sum(0) > 0
    for k in range(4):
        x = images[k, ...]  #
        y = x[mask]

        # 对背景外的区域进行归一化
        x[mask] -= y.mean()
        x[mask] /= y.std()
        images[k, ...] = x
    f = h5py.File(output, 'w')
    f.create_dataset('image', data=images, compression="gzip")
    f.close()


def doit(dset):
    root, out_path = dset['root'], dset['out']
    file_list = os.path.join(root, dset['flist'])
    subjects = open(file_list).read().splitlines()
    names = [sub for sub in subjects]
    paths = [os.path.join(root, name, name + '_') for name in names]

    for path in tqdm(paths):
        path = path.replace('\\', '/')
        process_h5(path, out_path)
        # 提取原始T1图像的仿射矩阵affine以及头文件header
        T1_img = nib.load(path + 'T1.nii')
        affine = T1_img.affine.copy()
        hdr = T1_img.header.copy()
    return affine, hdr


def test_single_case(net, image, stride_xy, stride_z, patch_size, num_classes=1):
    c, ww, hh, dd = image.shape

    sx = math.ceil((ww - patch_size[0]) / stride_xy) + 1
    sy = math.ceil((hh - patch_size[1]) / stride_xy) + 1
    sz = math.ceil((dd - patch_size[2]) / stride_z) + 1
    score_map = np.zeros((num_classes,) + image.shape[1:]).astype(np.float32)
    cnt = np.zeros(image.shape[1:]).astype(np.float32)

    for x in range(0, sx):
        xs = min(stride_xy * x, ww - patch_size[0])
        for y in range(0, sy):
            ys = min(stride_xy * y, hh - patch_size[1])
            for z in range(0, sz):
                zs = min(stride_z * z, dd - patch_size[2])
                test_patch = image[:, xs:xs + patch_size[0], ys:ys + patch_size[1], zs:zs + patch_size[2]]
                test_patch = np.expand_dims(test_patch, axis=0).astype(np.float32)
                test_patch = torch.from_numpy(test_patch).cuda()
                y1 = net(test_patch)
                y = F.softmax(y1, dim=1)
                y = y.cpu().data.numpy()
                y = y[0, :, :, :, :]
                score_map[:, xs:xs + patch_size[0], ys:ys + patch_size[1], zs:zs + patch_size[2]] \
                    = score_map[:, xs:xs + patch_size[0], ys:ys + patch_size[1], zs:zs + patch_size[2]] + y
                cnt[xs:xs + patch_size[0], ys:ys + patch_size[1], zs:zs + patch_size[2]] \
                    = cnt[xs:xs + patch_size[0], ys:ys + patch_size[1], zs:zs + patch_size[2]] + 1
    score_map = score_map / np.expand_dims(cnt, axis=0)
    label_map = np.argmax(score_map, axis=0)
    return label_map, score_map


def test_all_case(net, image_list, affine, hdr, num_classes=2, patch_size=(112, 112, 80), stride_xy=18, stride_z=4,
                  save_result=True,
                  test_save_path=None, preproc_fn=None):
    for ith, image_path in enumerate(image_list):
        h5f = h5py.File(image_path, 'r')
        image = h5f['image'][:]
        if preproc_fn is not None:
            image = preproc_fn(image)
        prediction, score_map = test_single_case(net, image, stride_xy, stride_z, patch_size, num_classes=num_classes)

        if save_result:
            nib.save(nib.Nifti1Image(prediction, affine, hdr),
                     test_save_path + "%02d_pred.nii" % ith) # 标签要保存为整型，不然再matlab中读的时候会有差异
            # image只保留一个模态
            # img = image[2]
            # nib.save(nib.Nifti1Image(img.astype(np.float32), affine, hdr), test_save_path + "%02d_img.nii.gz" % ith)


if __name__ == '__main__':
    affine, hdr = doit(train_set)
    data_path = './Unet/dataset'
    test_save_path = './Unet/prediction/'
    save_mode_path = './Unet/UNet.pth'
    net = UNet(in_channels=4, num_classes=4).cuda()
    net.load_state_dict(torch.load(save_mode_path)['model'])
    # print("init weight from {}".format(save_mode_path))
    net.eval()
    with open(data_path + '/../inference.txt', 'r') as f:
        image_list = [os.path.join(data_path, x.strip()) for x in f.readlines()]
    # 滑动窗口法
    test_all_case(net, image_list, affine, hdr,
                  num_classes=4, patch_size=(160, 160, 128), stride_xy=32, stride_z=16,
                  save_result=True, test_save_path=test_save_path)
