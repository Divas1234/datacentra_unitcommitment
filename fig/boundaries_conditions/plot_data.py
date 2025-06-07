import matplotlib.pyplot as plt

# Data extracted from OCR
punit1 = [12, 7, 5, 0, 0, 0, 0, 0, 3, 8, 13, 15, 15, 15, 13, 10, 7, 10, 13, 10, 5, 0, 0, 0]
punit2 = [10, 8, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
punit3 = [15, 20, 15, 10, 9, 15, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 15, 5, 0]

# Time axis
time = list(range(24))

# Plotting the data
plt.plot(time, punit1, label='Punit1')
plt.plot(time, punit2, label='Punit2')
plt.plot(time, punit3, label='Punit3')

# Adding labels and title
plt.xlabel('Time (h)')
plt.ylabel('Power Output (MW)')
plt.title('Power Output of Punits')

# Adding legend
plt.legend()

# Displaying the plot
plt.grid(True)
plt.savefig('power_output.png')
plt.show()