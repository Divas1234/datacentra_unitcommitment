import os
import numpy as np
import matplotlib
matplotlib.use('Agg')  # headless backend to avoid GUI/font issues
import matplotlib.pyplot as plt

# Ensure a writable MPL cache dir inside project
_mpl_dir = os.path.join(os.path.dirname(__file__), '.mplcache')
os.makedirs(_mpl_dir, exist_ok=True)
os.environ.setdefault('MPLCONFIGDIR', _mpl_dir)

# Scientific, muted palette (ColorBrewer Set2-like)
PALETTE_SCI = (
    '#66c2a5',  # teal
    '#fc8d62',  # orange
    '#8da0cb',  # blue-purple
    '#e78ac3',  # pink
    '#a6d854',  # green
    '#ffd92f',  # yellow
    '#e5c494',  # brown
    '#b3b3b3',  # grey
)


def compute_column_means(csv_path: str) -> np.ndarray:
    data = np.loadtxt(csv_path, delimiter=',')
    if data.ndim == 1:
        data = data.reshape(1, -1)
    return data.mean(axis=0)


def plot_radar(values: np.ndarray, labels: list[str], title: str, output_path: str) -> None:
    num_vars = len(values)
    angles = np.linspace(0, 2 * np.pi, num_vars, endpoint=False).tolist()
    values = values.tolist()
    values += values[:1]
    angles += angles[:1]

    fig, ax = plt.subplots(figsize=(4, 4), subplot_kw=dict(polar=True))
    ax.plot(angles, values, color='#1f77b4', linewidth=2)
    ax.fill(angles, values, color='#1f77b4', alpha=0.25)

    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(labels)
    ax.set_rlabel_position(0)

    # Set nice radial grid based on data range
    vmin, vmax = float(np.min(values[:-1])), float(np.max(values[:-1]))
    if vmax - vmin < 1e-6:
        vmin -= 0.01
        vmax += 0.01
    ax.set_ylim(vmin, vmax)

    ax.grid(alpha=0.3)
    ax.set_title(title, va='bottom', fontsize=10)
    plt.tight_layout()
    fig.savefig(output_path, dpi=200, bbox_inches='tight')
    # Save as PDF
    pdf_path = output_path.replace('.png', '.pdf')
    fig.savefig(pdf_path, format='pdf', dpi=200, bbox_inches='tight')


def plot_groups_of_eight(csv_path: str, base_out: str = 'dc_fv_lambda_radar_') -> None:
    data = np.loadtxt(csv_path, delimiter=',')
    if data.ndim == 1:
        data = data.reshape(1, -1)

    num_rows, num_dim = data.shape
    assert num_rows >= 40, 'Expect at least 40 rows to form 5 groups of 8.'

    labels = [f'F{i+1}' for i in range(num_dim)]

    # Use global min/max for consistent radial scale across figures
    global_min = float(np.min(data[:40, :]))
    global_max = float(np.max(data[:40, :]))

    for g in range(5):
        start = g * 8
        end = start + 8
        group = data[start:end, :]

        # Prepare radar axes
        num_vars = num_dim
        angles = np.linspace(0, 2 * np.pi, num_vars, endpoint=False).tolist()
        fig, ax = plt.subplots(figsize=(4.5, 4.5), subplot_kw=dict(polar=True))

        # Plot each of the 8 rows
        for idx in range(group.shape[0]):
            vals = group[idx, :].tolist()
            vals += vals[:1]
            angs = angles + angles[:1]
            ax.plot(angs, vals, linewidth=1.6, label=f'DCC{idx + 1}')
            ax.fill(angs, vals, alpha=0.08)

        ax.set_xticks(angles)
        ax.set_xticklabels(labels)
        ax.set_rlabel_position(0)
        # Apply global radial limits
        if abs(global_max - global_min) < 1e-9:
            rmin, rmax = global_min - 0.01, global_max + 0.01
        else:
            rmin, rmax = global_min, global_max
        ax.set_ylim(rmin, rmax)
        ax.grid(alpha=0.3)
        ax.set_title(f'DCC1-DCC8 Group {g + 1}', va='bottom', fontsize=10)
        ax.legend(loc='upper right', bbox_to_anchor=(1.2, 1.1), ncol=1, fontsize=7)

        plt.tight_layout()
        out_path = f'{base_out}{g + 1}.png'
        fig.savefig(out_path, dpi=220, bbox_inches='tight')
        # Save as PDF
        pdf_path = f'{base_out}{g + 1}.pdf'
        fig.savefig(pdf_path, format='pdf', dpi=220, bbox_inches='tight')
        plt.close(fig)
        print(f'Saved: {out_path} and {pdf_path} (rows {start + 1}-{end}, dims {num_dim})')


def plot_3d_bars_top8(csv_path: str, out_path: str = 'dc_fv_lambda_3d_top8.png') -> None:
    import matplotlib.pyplot as plt
    from mpl_toolkits.mplot3d import Axes3D  # noqa: F401 - needed for 3D projection

    data = np.loadtxt(csv_path, delimiter=',')
    if data.ndim == 1:
        data = data.reshape(1, -1)

    # Take first 8 rows
    top = data[:8, :]
    num_rows, num_dim = top.shape

    # Axes: x for feature index, y for row index, z for value
    xs = np.arange(num_dim)
    ys = np.arange(num_rows)

    # Create grid of bars
    xx, yy = np.meshgrid(xs, ys)
    xx_idx = xx.ravel()
    yy_idx = yy.ravel()
    zz = np.zeros_like(xx_idx, dtype=float)
    heights = top[yy_idx, xx_idx]

    # Bar sizes - position bars so center aligns with grid points
    bar_width = 0.6
    dx = np.full_like(xx_idx, bar_width, dtype=float)
    dy = np.full_like(yy_idx, bar_width, dtype=float)
    # Adjust positions so bars are centered on grid points
    xx_pos = xx_idx - bar_width / 2
    yy_pos = yy_idx - bar_width / 2

    # Muted scientific colors per row
    colors = [PALETTE_SCI[int(r) % len(PALETTE_SCI)] for r in yy_idx]

    fig = plt.figure(figsize=(7, 4))
    ax = fig.add_subplot(111, projection='3d')

    # Brighten look & feel
    ax.set_facecolor('white')
    for pane in [ax.xaxis.pane, ax.yaxis.pane, ax.zaxis.pane]:
        pane.set_facecolor((1.0, 1.0, 1.0, 0.95))
        pane.set_edgecolor((0.8, 0.8, 0.8, 0.6))
    ax.grid(color=(0.85, 0.85, 0.85), linewidth=0.6, alpha=0.8)

    ax.bar3d(xx_pos, yy_pos, zz, dx, dy, heights,
             color=colors, shade=True, alpha=0.85, edgecolor=(0.3, 0.3, 0.3, 0.9), linewidth=0.5)

    ax.set_xlabel('t (h)', fontsize=8)
    ax.set_ylabel('', fontsize=8)
    ax.set_zlabel('Value', labelpad=8, fontsize=8)
    # Title removed per request

    # Ticks and labels
    ax.set_xticks(np.arange(0, num_dim, max(1, num_dim // 12)))
    ax.set_xticklabels([str(i+1) for i in range(0, num_dim, max(1, num_dim // 12))], fontsize=7)
    ax.set_yticks(np.arange(num_rows))
    ax.set_yticklabels([f'DCC{i+1}' for i in range(num_rows)], fontsize=7)

    # Slightly nicer view angle
    ax.view_init(elev=22, azim=-55)

    # No legend per request

    # Increase margins to avoid clipping z-label, but tighter without title
    fig.subplots_adjust(left=0.08, right=0.96, top=0.98, bottom=0.08)
    fig.savefig(out_path, dpi=220, bbox_inches='tight', pad_inches=0.2)
    # Save as PDF
    pdf_path = out_path.replace('.png', '.pdf')
    fig.savefig(pdf_path, format='pdf', dpi=220, bbox_inches='tight', pad_inches=0.2)
    plt.close(fig)
    print(f'Saved: {out_path} and {pdf_path} (top 8 rows, dims {num_dim})')


def plot_3d_bars_group(csv_path: str, start_row: int, out_path: str) -> None:
    """Plot a 3D bar chart for 8 rows starting at start_row (1-based)."""
    import matplotlib.pyplot as plt
    from mpl_toolkits.mplot3d import Axes3D  # noqa: F401

    data = np.loadtxt(csv_path, delimiter=',')
    if data.ndim == 1:
        data = data.reshape(1, -1)

    # slice rows [start_row-1, start_row+7)
    sr = max(1, start_row)
    er = sr + 8
    subset = data[sr-1:er-1, :]
    num_rows, num_dim = subset.shape

    xs = np.arange(num_dim)
    ys = np.arange(num_rows)
    xx, yy = np.meshgrid(xs, ys)
    xx_idx = xx.ravel()
    yy_idx = yy.ravel()
    zz = np.zeros_like(xx_idx, dtype=float)
    heights = subset[yy_idx, xx_idx]

    # Bar sizes - position bars so center aligns with grid points
    bar_width = 0.6
    dx = np.full_like(xx_idx, bar_width, dtype=float)
    dy = np.full_like(yy_idx, bar_width, dtype=float)
    # Adjust positions so bars are centered on grid points
    xx_pos = xx_idx - bar_width / 2
    yy_pos = yy_idx - bar_width / 2

    # Muted scientific colors per row
    colors = [PALETTE_SCI[int(r) % len(PALETTE_SCI)] for r in yy_idx]

    fig = plt.figure(figsize=(7, 4))
    ax = fig.add_subplot(111, projection='3d')
    ax.set_facecolor('white')
    for pane in [ax.xaxis.pane, ax.yaxis.pane, ax.zaxis.pane]:
        pane.set_facecolor((1.0, 1.0, 1.0, 0.95))
        pane.set_edgecolor((0.8, 0.8, 0.8, 0.6))
    ax.grid(color=(0.85, 0.85, 0.85), linewidth=0.6, alpha=0.8)

    ax.bar3d(xx_pos, yy_pos, zz, dx, dy, heights,
             color=colors, shade=True, alpha=0.85, edgecolor=(0.3, 0.3, 0.3, 0.9), linewidth=0.5)

    ax.set_xlabel('t (h)', fontsize=8)
    ax.set_ylabel('', fontsize=8)
    ax.set_zlabel('Value', labelpad=8, fontsize=8)
    # Title removed per request

    ax.set_xticks(np.arange(0, num_dim, max(1, num_dim // 12)))
    ax.set_xticklabels([str(i+1) for i in range(0, num_dim, max(1, num_dim // 12))], fontsize=7)
    ax.set_yticks(np.arange(num_rows))
    ax.set_yticklabels([f'DCC{i + 1}' for i in range(num_rows)], fontsize=7)

    ax.view_init(elev=22, azim=-55)

    # Increase margins to avoid clipping z-label, but tighter without title
    fig.subplots_adjust(left=0.08, right=0.96, top=0.98, bottom=0.08)
    fig.savefig(out_path, dpi=220, bbox_inches='tight', pad_inches=0.2)
    # Save as PDF
    pdf_path = out_path.replace('.png', '.pdf')
    fig.savefig(pdf_path, format='pdf', dpi=220, bbox_inches='tight', pad_inches=0.2)
    plt.close(fig)
    print(f'Saved: {out_path} and {pdf_path} (DCC1-DCC8, dims {num_dim})')


def stitch_images_horiz(paths: list[str], out_path: str) -> None:
    from PIL import Image
    imgs = [Image.open(p) for p in paths]
    # Normalize heights to the smallest height, keep aspect
    min_h = min(img.height for img in imgs)
    resized = []
    for img in imgs:
        w, h = img.size
        new_w = int(w * (min_h / h))
        resized.append(img.resize((new_w, min_h), Image.LANCZOS))
    total_w = sum(img.width for img in resized)
    canvas = Image.new('RGB', (total_w, min_h), (255, 255, 255))
    x = 0
    for img in resized:
        canvas.paste(img, (x, 0))
        x += img.width
    canvas.save(out_path)
    # Save as PDF using matplotlib
    pdf_path = out_path.replace('.png', '.pdf')
    import matplotlib.pyplot as plt
    import numpy as np
    img_array = np.array(canvas)
    fig, ax = plt.subplots(figsize=(total_w/200, min_h/200), dpi=200)
    ax.imshow(img_array)
    ax.axis('off')
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    fig.savefig(pdf_path, format='pdf', bbox_inches='tight', pad_inches=0, dpi=300)
    plt.close(fig)
    print(f'Stitched: {out_path} and {pdf_path}')


def stitch_pairs_grid(pairs: list[tuple[str, str]], out_path: str) -> None:
    """Stitch 5 pairs of images into a 5x2 grid (rows = pairs).
    Each row: [left (dc_fv), right (dc_fv_lambda)]. Heights are normalized within each row.
    Rows are padded to the same width and stacked vertically with compact spacing.
    Labels (a), (b), ... are added below each subplot.
    """
    from PIL import Image, ImageDraw, ImageFont

    row_images: list[Image.Image] = []
    row_widths: list[int] = []
    row_heights: list[int] = []
    left_widths: list[int] = []

    for left_path, right_path in pairs:
        left = Image.open(left_path).convert('RGB')
        right = Image.open(right_path).convert('RGB')
        # Normalize heights within the pair
        target_h = min(left.height, right.height)
        def resize_keep_h(img: Image.Image, h: int) -> Image.Image:
            w, hh = img.size
            new_w = int(round(w * (h / hh)))
            return img.resize((new_w, h), Image.LANCZOS)
        left_r = resize_keep_h(left, target_h)
        right_r = resize_keep_h(right, target_h)

        row_w = left_r.width + right_r.width
        row_h = target_h
        row = Image.new('RGB', (row_w, row_h), (255, 255, 255))
        row.paste(left_r, (0, 0))
        row.paste(right_r, (left_r.width, 0))

        row_images.append(row)
        row_widths.append(row_w)
        row_heights.append(row_h)
        left_widths.append(left_r.width)

    # Label height and spacing - very compact
    label_h = 16
    row_gap = 0  # No vertical spacing between rows
    grid_w = max(row_widths)
    grid_h = sum(row_heights) + len(pairs) * (label_h + row_gap) - row_gap  # -row_gap to avoid extra space at bottom
    
    canvas = Image.new('RGB', (grid_w, grid_h), (255, 255, 255))
    draw = ImageDraw.Draw(canvas)
    
    # Try to use a nice font, fallback to default - make it larger and bold
    font_size = 18
    try:
        font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', font_size)
    except:
        try:
            font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf', font_size)
        except:
            try:
                font = ImageFont.truetype('Arial.ttf', font_size)
            except:
                # Use default font but make it larger
                font = ImageFont.load_default()

    y = 0
    label_idx = 0
    for row, row_w, row_h, left_w in zip(row_images, row_widths, row_heights, left_widths):
        # pad each row to grid width (centered)
        pad_left = (grid_w - row_w) // 2
        canvas.paste(row, (pad_left, y))
        
        # Add labels below each subplot - centered
        # Left label
        left_center_x = pad_left + left_w // 2
        left_label = f'({chr(ord("a") + label_idx)})'
        left_bbox = draw.textbbox((0, 0), left_label, font=font)
        left_text_w = left_bbox[2] - left_bbox[0]
        left_text_h = left_bbox[3] - left_bbox[1]
        left_text_x = left_center_x - left_text_w // 2
        left_text_y = y + row_h - 2  # Overlapping slightly with image bottom
        draw.text((left_text_x, left_text_y), left_label, fill=(0, 0, 0), font=font)
        
        # Right label
        label_idx += 1
        right_center_x = pad_left + left_w + (row_w - left_w) // 2
        right_label = f'({chr(ord("a") + label_idx)})'
        right_bbox = draw.textbbox((0, 0), right_label, font=font)
        right_text_w = right_bbox[2] - right_bbox[0]
        right_text_x = right_center_x - right_text_w // 2
        right_text_y = y + row_h - 2  # Overlapping slightly with image bottom
        draw.text((right_text_x, right_text_y), right_label, fill=(0, 0, 0), font=font)
        
        label_idx += 1
        y += row_h + label_h + row_gap

    # Save as PDF using matplotlib
    if out_path.endswith('.png'):
        pdf_path = out_path.replace('.png', '.pdf')
        # Convert PIL Image to numpy array and save with matplotlib
        import matplotlib.pyplot as plt
        import numpy as np
        img_array = np.array(canvas)
        fig, ax = plt.subplots(figsize=(grid_w/200, grid_h/200), dpi=200)
        ax.imshow(img_array)
        ax.axis('off')
        plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
        fig.savefig(pdf_path, format='pdf', bbox_inches='tight', pad_inches=0, dpi=300)
        plt.close(fig)
        print(f'Stitched grid (PDF): {pdf_path}')
    else:
        canvas.save(out_path)
        print(f'Stitched grid: {out_path}')
def generate_3d_set(csv_path: str, prefix: str) -> None:
    # First group 1-8
    top_out = f'{prefix}_3d_top8.png'
    plot_3d_bars_top8(csv_path, top_out)
    # Other groups and stitch
    outs = [top_out]
    for base in [9, 17, 25, 33]:
        outp = f'{prefix}_3d_rows_{base:02d}_{base+7:02d}.png'
        plot_3d_bars_group(csv_path, base, outp)
        outs.append(outp)
    stitch_images_horiz(outs, f'{prefix}_3d_all.png')


if __name__ == '__main__':
    # dc_fv_lambda.csv
    generate_3d_set('dc_fv_lambda.csv', 'dc_fv_lambda')
    # dc_fv.csv
    generate_3d_set('dc_fv.csv', 'dc_fv')
    # Build 5x2 grid: pair corresponding groups (lambda on left, dc_fv on right)
    pair_list = [
        ('dc_fv_3d_top8.png', 'dc_fv_lambda_3d_top8.png'),
        ('dc_fv_3d_rows_09_16.png', 'dc_fv_lambda_3d_rows_09_16.png'),
        ('dc_fv_3d_rows_17_24.png', 'dc_fv_lambda_3d_rows_17_24.png'),
        ('dc_fv_3d_rows_25_32.png', 'dc_fv_lambda_3d_rows_25_32.png'),
        ('dc_fv_3d_rows_33_40.png', 'dc_fv_lambda_3d_rows_33_40.png'),
    ]
    stitch_pairs_grid(pair_list, 'dc_fv_lambda_vs_dc_fv_3d_grid_5x2.png')
